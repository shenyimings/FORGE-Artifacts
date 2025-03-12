// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {OwnableUpgradeable as Ownable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {PausableUpgradeable as Pausable} from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import {ReentrancyGuardUpgradeable as ReentrancyGuard} from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {IERC20Upgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable as SafeERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interfaces/AggregatorV3Interface.sol";
import "./interfaces/ILP.sol";
import "./interfaces/IMasterMantis.sol";
import "./interfaces/IPoolHelper.sol";

contract Pool is Initializable, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event AddLP(address indexed token, address indexed lpToken, address indexed _feed);
    event RemoveLP(address indexed token);
    event LPRatioUpdated(uint256 indexed lpRatio);
    event RiskUpdated(address indexed token, uint256 risk);

    event Deposit(address indexed caller, address indexed receiver, address indexed token, uint256 amount, uint256 lpAmount, bool autoStake);
    event Withdraw(address indexed caller, address indexed receiver, address indexed token, uint256 lpAmount, uint256 amount);
    event WithdrawOther(address indexed caller, address indexed receiver, address indexed token, address otherToken, uint256 lpAmount, uint256 otherAmount);
    event Swap(address indexed caller, address indexed receiver, address indexed from, uint256 fromAmount, address to, uint256 toAmount);
    event OneTapped(address indexed caller, address indexed receiver, address indexed from, address to, uint256 fromLpAmount, uint256 toLpAmount);

    IMasterMantis public masterMantis;
    IPoolHelper private poolHelper;
    address public treasury;

    uint256 public lpRatio;         // 6 decimals
    uint256 private constant ONE_18 = 1e18;

    // Prevents stack too deep error
    struct SwapHelper {
        ILP fromLp;
        ILP toLp;
        uint256 toAmount;
        uint256 treasuryFees;
        uint256 lpAmount;
    }

    // Prevents stack too deep error
    struct OneTapHelper {
        uint256 withdrawAmount;
        uint256 withdrawFees;
        uint256 depositLpAmount;
        uint256 depositFees;
        uint256 fromTreasuryFees;
        uint256 toTreasuryFees;
        uint256 fromAsset;
        uint256 fromLiability;
        uint256 toAsset;
        uint256 toLiability;
    }

    // token -> LP
    mapping(address => address) public tokenLPs;
    ILP[] public lpList;

    // LP -> feed
    mapping(address => address) public priceFeeds;

    uint256 public slippageA;       // Determines the max slippage of the curve. It has 1 decimal place, so 8 = 0.8
    uint256 public slippageN;       // Determines the slope of the curve. Must be > 0.
    uint256 public slippageK;       // The liquidity ratio where the curve equation changes. Value is 18 decimals

    bool public swapAllowed;

    // LP -> risk
    mapping(address => uint256) public riskProfile;


    modifier checkDeadline(uint256 deadline) {
        require(block.timestamp <= deadline, 'Expired');
        _;
    }

    modifier checkZeroAmount(uint256 amount) {
        require(amount > 0, 'ZERO');
        _;
    }

    modifier checkNullAddress(address _address) {
        require(_address != address(0), 'ZERO');
        _;
    }    

    function initialize(address _masterMantis, address _treasury, address _poolHelper) external initializer {
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();
        require(_treasury != address(0), "ZERO");
        require(_poolHelper != address(0), "ZERO");
        if (_masterMantis != address(0)) {
        	masterMantis = IMasterMantis(_masterMantis);
        }
        treasury = _treasury;
        poolHelper = IPoolHelper(_poolHelper);
        slippageA = 8;
        slippageN = 12;
        slippageK = ONE_18;
    }

    function setSlippageParams(uint256 _slippageA, uint256 _slippageN) external onlyOwner {
        require(_slippageA > 0, "ZERO");
        require(_slippageN > 0, "ZERO");
        slippageA = _slippageA;
        slippageN = _slippageN;
    }

    function setPoolHelper(address _poolHelper) external onlyOwner checkNullAddress(_poolHelper) {
        poolHelper = IPoolHelper(_poolHelper);
    }

    function setMasterMantis(address _masterMantis) external onlyOwner checkNullAddress(_masterMantis) {
    	masterMantis = IMasterMantis(_masterMantis);
    }

    function setTreasury(address _treasury) external onlyOwner checkNullAddress(_treasury) {
        treasury = _treasury;
    }

    function setRiskProfile(address _token, uint256 _risk) external onlyOwner checkNullAddress(_token) {
        address _lpToken = tokenLPs[_token];
        riskProfile[_lpToken] = _risk;
        emit RiskUpdated(_token, _risk);
    }

    function setSwapAllowed(bool _swapAllowed) external onlyOwner {
        swapAllowed = _swapAllowed;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function addLP(address _token, address _lpToken, address _feed) external checkNullAddress(_token) checkNullAddress(_lpToken) checkNullAddress(_feed) onlyOwner {
        tokenLPs[_token] = _lpToken;
        priceFeeds[_lpToken] = _feed;
        lpList.push(ILP(_lpToken));
        emit AddLP(_token, _lpToken, _feed);
    }

    function setLPFeed(address _token, address _feed) external checkNullAddress(_token) checkNullAddress(_feed) onlyOwner {
        address _lpToken = tokenLPs[_token];
        priceFeeds[_lpToken] = _feed;
    }

    function removeLP(address _token, uint index) external checkNullAddress(_token) onlyOwner {
        ILP lpToken = getLP(_token);
        require(lpList[index] == lpToken, "Wrong index");
        tokenLPs[_token] = address(0);
        uint lastLpIndex = lpList.length - 1;
        lpList[index] = lpList[lastLpIndex];
        lpList.pop();
        emit RemoveLP(_token);
    }

    function setLpRatio(uint256 _lpRatio) external onlyOwner {
        require(_lpRatio <= 100, ">0.01%");
        lpRatio = _lpRatio;
        emit LPRatioUpdated(_lpRatio);
    }

    function getLP(address _token) public view returns (ILP) {
        require(tokenLPs[_token] != address(0), "No LP");
        return ILP(tokenLPs[_token]);
    }

    /// @notice Get the current treasury fees
    /// @return fees in 6 decimal places. 1e6 = 100%
    function _getTreasuryRatio(uint256 nlr) internal pure returns (uint256) {
        if (nlr < ONE_18) {
            return 0;
        } else if (nlr < 1.05e18) {
            return 4e5;
        } else {
            return 8e5;
        }
    }

    /// @notice Get the current one tap factor
    /// @return value in 6 decimal places. 1e6 = 100% fees
    function _getOneTapFactor(uint256 nlr) internal pure returns (uint256) {
        if (nlr < ONE_18) {
            return 1e6;
        } else if (nlr < 1.05e18) {
            return 8e5;
        } else {
            return 4e5;
        }
    }

    /// @notice Get the current swap fees excluding lp fees
    /// @return swapFee in 6 decimal places. 1e6 = 100%
    function _getSwapFeeRatio(uint256 nlr) internal view returns (uint256 swapFee) {
        if (nlr < 0.96e18) {
            swapFee = 400;     // 0.04%
        } else if (nlr < ONE_18) {
            swapFee = 250;
        } else {
            swapFee = 100;     // 0.01%
        }
        return swapFee - lpRatio;
    }

    function _getSlippage(uint256 lr) internal view returns (uint256) {
        return poolHelper.getSlippage(lr, slippageA, slippageN, slippageK);
    }

    function getNetLiquidityRatio() public view returns (uint256) {
        (uint256 totalAsset, uint256 totalLiability) = _getTotalAssetLiability(address(0), address(0), 0);
        if (totalLiability == 0) {
            return ONE_18;
        } else {
            return (totalAsset * ONE_18) / totalLiability;
        }
    }

    function checkRiskProfile(address fromLp, address toLp, uint256 toAmount) public view returns (bool) {
        uint256 risk = riskProfile[address(fromLp)];
        if (risk == 0) {
            return true;
        }
        (uint256 totalAsset, uint256 totalLiability) = _getTotalAssetLiability(fromLp, toLp, toAmount);
        if (totalLiability == 0) {
            return true;
        } else {
            return ((totalAsset * ONE_18) / totalLiability) >= risk;
        }
    }

    function _getTotalAssetLiability(address fromLp, address toLp, uint256 toAmount) internal view returns (uint256 totalAsset, uint256 totalLiability) {
        for (uint i = 0; i < lpList.length; i++) {
            ILP lp = lpList[i];
            if (address(lp) != fromLp) {
                uint256 price = tokenOraclePrice(address(lp));
                uint256 lpAsset = lp.asset();
                if (address(lp) == toLp) {
                    lpAsset -= toAmount;
                }
                totalAsset += (lpAsset * price) / (10 ** lp.decimals());
                totalLiability += (lp.liability() * price) / (10 ** lp.decimals());
            }
        }
    }

    /// @notice Deposit stable assets into the pool
    /// @param token Token address
    /// @param recipient Recipient address
    /// @param amount Amount of token to deposit
    /// @param autoStake If the lp tokens obtained should be auto-staked into the MasterMantis contract
    /// @param deadline Timestamp before which the txn should be completed
    function deposit(
        address token,
        address recipient,
        uint256 amount,
        bool autoStake,
        uint256 deadline
    ) external whenNotPaused nonReentrant checkDeadline(deadline) checkZeroAmount(amount) checkNullAddress(recipient) {
        ILP lpToken = getLP(token);
        address lpTokenAddress = address(lpToken);
        IERC20(token).safeTransferFrom(msg.sender, lpTokenAddress, amount);
        uint256 lpAmount;
        if (autoStake) {
            lpAmount = _deposit(lpToken, address(this), amount);
            uint256 pid = masterMantis.getTokenPid(lpTokenAddress);
            lpToken.approve(address(masterMantis), lpAmount);
            masterMantis.deposit(recipient, pid, lpAmount);
        } else {
            lpAmount = _deposit(lpToken, recipient, amount);
        }
        emit Deposit(msg.sender, recipient, token, amount, lpAmount, autoStake);
    }

    /// @notice Mints the required no. of LP tokens to recipient
    /// @param lpToken LP Token address
    /// @param recipient Recipient address
    /// @param amount Amount of token to deposit
    /// @return LP tokens minted
    function _deposit(ILP lpToken, address recipient, uint256 amount) internal returns (uint256) {
        (uint256 lpAmount, uint256 fees, uint256 treasuryFees) = getDepositAmount(lpToken, amount, false, 0);
        require(lpAmount > 0, "ERR");
        
        lpToken.mint(recipient, recipient, lpAmount);
        if (treasuryFees > 0) {
            lpToken.withdrawUnderlyer(treasury, treasuryFees);
        }
        lpToken.updateAssetLiability(amount - treasuryFees, true, amount - fees, true);
        return lpAmount;
    }

    /// @notice Calculates the amount of LP tokens to be minted on deposit and the corresponding fees
    /// @param lpToken LP Token address
    /// @param amount Amount of token to deposit
    /// @param isOneTap Whether One-Tap functionality is being used. This only affects the fees to be charged
    /// @param asset Asset value of the token. Required only when isOneTap is true
    /// @return lpAmount LP tokens to be minted
    /// @return fees Total Fees to be charged
    /// @return treasuryFees Part of fees transferred to treasury
    function getDepositAmount(ILP lpToken, uint256 amount, bool isOneTap, uint256 asset) public view returns (uint256 lpAmount, uint256 fees, uint256 treasuryFees) {
        if (!isOneTap) {
            asset = lpToken.asset();
        }
        uint256 liability = lpToken.liability();

        if (liability > 0) {
            uint256 currentLR = (asset * ONE_18) / liability;
            if (currentLR > ONE_18) {
                uint256 newLR = ((asset + amount) * ONE_18) / (liability + amount);
                uint256 nlr = getNetLiquidityRatio();
                uint256 maxLR = lpToken.getMaxLR();
                uint256 positiveFees = ((liability + amount) * _getSlippage(newLR)) + (liability * _getSlippage(maxLR));
                uint256 negativeFees = (liability * _getSlippage(currentLR)) + ((liability + amount) * _getSlippage((maxLR*liability+ONE_18*amount) / (liability + amount)));
                if (positiveFees > negativeFees) {
                    fees = (positiveFees - negativeFees) / ONE_18;
                    if (fees > amount) fees = amount;
                }
                if (isOneTap) {
                    fees = fees * _getOneTapFactor(nlr) / 1e6;
                }
                treasuryFees = fees * _getTreasuryRatio(nlr) / 1e6;
            }
        }

        lpAmount = liability == 0 ? amount : (amount - fees) * lpToken.totalSupply() / liability;
    }

    /// @notice Withdraw stable assets back from the pool
    /// @param token Token address of the underlying LP
    /// @param recipient Recipient address
    /// @param lpAmount Amount of LP token being used to withdraw
    /// @param minAmount The minimum amount of token accepted, below which the txn will fail
    /// @param deadline Timestamp before which the txn should be completed
    function withdraw(
        address token,
        address recipient,
        uint256 lpAmount,
        uint256 minAmount,
        uint256 deadline
    ) external whenNotPaused nonReentrant checkDeadline(deadline) checkZeroAmount(lpAmount) checkNullAddress(recipient) {
        ILP lpToken = getLP(token);
        (uint256 amount, uint256 fees, uint256 treasuryFees) = getWithdrawAmount(lpToken, lpAmount, false);
        uint256 finalAmount = amount - fees;
        require(finalAmount >= minAmount, "TOO LOW");

        lpToken.burnFrom(msg.sender, msg.sender, lpAmount);
        lpToken.withdrawUnderlyer(recipient, finalAmount);
        if (treasuryFees > 0) {
            lpToken.withdrawUnderlyer(treasury, treasuryFees);
        }
        lpToken.updateAssetLiability(finalAmount + treasuryFees, false, amount, false);
        emit Withdraw(msg.sender, recipient, token, lpAmount, finalAmount);
    }

    /// @notice Withdraw stable assets back from the pool
    /// @param token Token address of the underlying
    /// @param otherToken Token address of the asset which will be withdrawn
    /// @param recipient Recipient address
    /// @param lpAmount Amount of LP token being used to withdraw
    /// @param minAmount The minimum amount of token accepted, below which the txn will fail
    /// @param deadline Timestamp before which the txn should be completed
    function withdrawOther(
        address token,
        address otherToken,
        address recipient,
        uint256 lpAmount,
        uint256 minAmount,
        uint256 deadline
    ) external whenNotPaused nonReentrant checkDeadline(deadline) checkZeroAmount(lpAmount) checkNullAddress(recipient) {
        ILP lpToken = getLP(token);
        ILP otherLpToken = getLP(otherToken);
        (uint256 amount, uint256 otherAmount) = getWithdrawAmountOtherToken(lpToken, otherLpToken, lpAmount);
        require(otherAmount >= minAmount, "LOW AMT");

        lpToken.burnFrom(msg.sender, msg.sender, lpAmount);
        lpToken.updateAssetLiability(0, false, amount, false);
        otherLpToken.updateAssetLiability(otherAmount, false, 0, false);
        otherLpToken.withdrawUnderlyer(recipient, otherAmount);
        emit WithdrawOther(msg.sender, recipient, token, otherToken, lpAmount, otherAmount);
    }

    /// @notice Calculates the amount of tokens to be withdrawn and the corresponding fees
    /// @param lpToken LP Token address
    /// @param lpAmount Amount of LP tokens to burn
    /// @param isOneTap Whether One-Tap functionality is being used. This only affects the fees to be charged
    /// @return amount token amount to be withdrawn
    /// @return fees Total Fees to be charged
    /// @return treasuryFees Part of fees transferred to treasury
    function getWithdrawAmount(ILP lpToken, uint256 lpAmount, bool isOneTap) public view returns (uint256 amount, uint256 fees, uint256 treasuryFees) {
        uint256 asset = lpToken.asset();
        uint256 liability = lpToken.liability();
        amount = lpAmount * liability / lpToken.totalSupply();
        require(asset >= amount, "LOW ASSET");
        if(liability > amount) {
            uint256 currentLR = (asset * ONE_18) / liability;
            if (currentLR < ONE_18) {
                uint256 newLR = ((asset - amount) * ONE_18) / (liability - amount);
                uint256 currentSlippage = _getSlippage(currentLR);
                uint256 newSlippage = _getSlippage(newLR);
                uint256 nlr = getNetLiquidityRatio();
                fees = (newSlippage - currentSlippage) * (liability - amount) / ONE_18;
                if (nlr < ONE_18 && amount > fees) {
                    fees += (amount - fees) * (ONE_18 - nlr) / ONE_18;
                }
                if (isOneTap) {
                    fees = fees * _getOneTapFactor(nlr) / 1e6;
                }
                treasuryFees = fees * _getTreasuryRatio(nlr) / 1e6;
            }
        }
    }

    /// @notice Calculates the amount of tokens to be withdrawn in other token (no fees)
    /// @param lpToken LP Token address
    /// @param otherLpToken Other LP Token address
    /// @param lpAmount Amount of LP tokens to burn
    /// @return amount token amount which should have been withdrawn. This is used to update liability
    /// @return otherAmount Amount of other tokens to withdraw
    function getWithdrawAmountOtherToken(ILP lpToken, ILP otherLpToken, uint256 lpAmount) public view returns (uint256 amount, uint256 otherAmount) {
        uint256 otherLiability = otherLpToken.liability();
        require(otherLiability > 0, "ERR");

        uint256 otherLpAmount = (lpAmount * (10 ** otherLpToken.decimals())) / (10 ** lpToken.decimals());
        otherAmount = otherLpAmount * otherLiability / otherLpToken.totalSupply();

        uint256 otherLR = ((otherLpToken.asset() - otherAmount) * ONE_18) / otherLiability;
        require(otherLR >= ONE_18, "LR low");
        
        uint256 lpTokenLiability = lpToken.liability();
        amount = lpAmount * lpTokenLiability / lpToken.totalSupply();
        require(lpTokenLiability > amount, "DIV BY 0");
        uint256 lpTokenLR = (lpToken.asset() * ONE_18) / (lpTokenLiability - amount);
        require(otherLR >= lpTokenLR, "From LR higher");
    }

    /// @notice Swap between from and to tokens.
    /// @param from From token address 
    /// @param from To token address 
    /// @param recipient Address of recipient
    /// @param amount Amount of from tokens
    /// @param minAmount Minimum amount of to tokens accepted, below which txn fails
    /// @param deadline Timestamp before which the txn should be completed
    function swap(
        address from,
        address to,
        address recipient,
        uint256 amount,
        uint256 minAmount,
        uint256 deadline
    ) external whenNotPaused nonReentrant checkDeadline(deadline) checkZeroAmount(amount) checkNullAddress(recipient) {
        SwapHelper memory vars;
        vars.fromLp = getLP(from);
        vars.toLp = getLP(to);
        require(vars.fromLp != vars.toLp, "ERR");
        (vars.toAmount, , vars.treasuryFees, vars.lpAmount) = getSwapAmount(vars.fromLp, vars.toLp, amount, false, 0, 0);
        require(vars.toAmount >= minAmount, "LOW AMT");
        IERC20(from).safeTransferFrom(msg.sender, address(vars.fromLp), amount);
        vars.fromLp.updateAssetLiability(amount, true, 0, false);
        vars.toLp.withdrawUnderlyer(recipient, vars.toAmount);
        if (vars.treasuryFees > 0) {
            vars.toLp.withdrawUnderlyer(treasury, vars.treasuryFees);
        }
        vars.toLp.updateAssetLiability(vars.toAmount + vars.treasuryFees, false, vars.lpAmount, true);
        emit Swap(msg.sender, recipient, from, amount, to, vars.toAmount);
    }

    /// @notice Get expected amount on a swap
    /// @param fromLp From LP token address 
    /// @param toLp To LP token address 
    /// @param amount Amount of from tokens
    /// @param isOneTap Whether One-Tap functionality is being used. This only affects the fees to be charged
    /// @param fromAsset Asset value of from token. Required only when isOneTap is true
    /// @param fromLiability Liability value of from token. Required only when isOneTap is true
    /// @return toAmount Amount of to tokens
    /// @return feeAmount Swap fees charged
    /// @return treasuryFees Part of swap fees given to treasury
    /// @return lpAmount LP fees given to LPs
    function getSwapAmount(
        ILP fromLp,
        ILP toLp,
        uint256 amount,
        bool isOneTap,
        uint256 fromAsset,
        uint256 fromLiability
    ) public view returns (uint256 toAmount, uint256 feeAmount, uint256 treasuryFees, uint256 lpAmount) {
        require(swapAllowed, "CANNOT");
        uint256 adjustedToAmount = ( amount * (10 ** toLp.decimals()) ) / (10 ** fromLp.decimals());
        if (!isOneTap) {
            fromAsset = fromLp.asset();
            fromLiability = fromLp.liability();
        }
        uint256 toAsset = toLp.asset();
        uint256 toLiability = toLp.liability();

        require(toAsset >= adjustedToAmount, "LOW ASSET");

        toAmount = adjustedToAmount * _getSwapSlippageFactor(
            fromAsset * ONE_18 / fromLiability,
            (fromAsset + amount) * ONE_18 / fromLiability,
            toAsset * ONE_18 / toLiability,
            (toAsset - adjustedToAmount) * ONE_18 / toLiability
        ) / ONE_18;
        require(checkRiskProfile(address(fromLp), address(toLp), toAmount), "ERR");
        
        uint256 nlr = getNetLiquidityRatio();
        feeAmount = toAmount * _getSwapFeeRatio(nlr) / 1e6;
        if (!isOneTap) {
            lpAmount = toAmount * lpRatio / 1e6;
        }
        toAmount = toAmount - (feeAmount + lpAmount);
        treasuryFees = feeAmount * _getTreasuryRatio(nlr) / 1e6;
    }

    /// @notice Get swap slippage during a swap
    /// @param oldFromLR Liquidity ratio of from token before swap
    /// @param newFromLR Liquidity ratio of from token after swap
    /// @param oldToLR Liquidity ratio of to token before swap
    /// @param newToLR Liquidity ratio of to token after swap
    function _getSwapSlippageFactor(
        uint256 oldFromLR,
        uint256 newFromLR,
        uint256 oldToLR,
        uint256 newToLR
    ) internal view returns (uint256 toFactor) {
        int256 negativeFromSlippage;
        int256 negativeToSlippage;
        int256 basisPoint = 1e18;
        if (newFromLR > oldFromLR) {
            negativeFromSlippage = (int256(_getSlippage(oldFromLR)) - int256(_getSlippage(newFromLR))) * basisPoint / int256(newFromLR - oldFromLR);
        }
        if (oldToLR > newToLR) {
            negativeToSlippage = (int256(_getSlippage(newToLR)) - int256(_getSlippage(oldToLR))) * basisPoint / int256(oldToLR - newToLR);
        }

        int256 toFactorSigned = basisPoint + negativeFromSlippage - negativeToSlippage;
        if (toFactorSigned > 2e18) toFactorSigned = 2e18;
        else if (toFactorSigned < 0) toFactorSigned = 0;
        toFactor = uint256(toFactorSigned);
    }

    /// @notice Condenses the operations Withdraw->Swap->Deposit into a sinple operation.
    /// @notice If user is staked, allow user to use the staked amount directly
    /// @notice Provides a fees discount on withdraw/swap/deposit depending on nlr value.
    /// @param from address of from token
    /// @param to address of to token
    /// @param recipient address of recipient
    /// @param lpAmount Amount of from LP tokens to be used in one-tap
    /// @param minAmount Minimum amount of to LP tokens desired, below which txn fails
    /// @param autoWithdraw Uses the from LP tokens which are staked in MasterMantis contract
    /// @param autoStake Stakes the to LP tokens received into MasterMantis contract
    /// @return helper Contains all the amount and fees information during the one-tap
    function oneTap(
        address from,
        address to,
        address recipient,
        uint256 lpAmount,
        uint256 minAmount,
        bool autoWithdraw,
        bool autoStake
    ) external whenNotPaused nonReentrant checkZeroAmount(lpAmount) returns (OneTapHelper memory helper) {
        ILP fromLp = getLP(from);
        ILP toLp = getLP(to);
        helper = getOneTapAmount(fromLp, toLp, lpAmount);
        require(helper.depositLpAmount >= minAmount, "Below minimum");

        fromLp.updateAssetLiability(
            fromLp.asset() > helper.fromAsset ? fromLp.asset() - helper.fromAsset : 0,
            false,
            helper.withdrawAmount,
            false
        );
        toLp.updateAssetLiability(
            toLp.asset() > helper.toAsset ? toLp.asset() - helper.toAsset : 0,
            false,
            helper.toLiability - toLp.liability(),
            true
        );
        
        fromLp.withdrawUnderlyer(treasury, helper.fromTreasuryFees);
        toLp.withdrawUnderlyer(treasury, helper.toTreasuryFees);

        if (autoWithdraw) {
            uint256 pid = masterMantis.getTokenPid(address(fromLp));
            masterMantis.withdrawFor(msg.sender, pid, lpAmount);
            fromLp.burnFrom(address(this), msg.sender, lpAmount);
        } else {
            fromLp.burnFrom(msg.sender, msg.sender, lpAmount);
        }
        if (autoStake) {
            toLp.mint(address(this), recipient, helper.depositLpAmount);
            uint256 pid = masterMantis.getTokenPid(address(toLp));
            toLp.approve(address(masterMantis), helper.depositLpAmount);
            masterMantis.deposit(recipient, pid, helper.depositLpAmount);
        } else {
            toLp.mint(recipient, recipient, helper.depositLpAmount);
        }

        emit OneTapped(msg.sender, recipient, from, to, lpAmount, helper.depositLpAmount);
    }

    /// @notice Get the one tap amount and fees info if a one-tap is performed
    /// @param fromLp address of from LP token
    /// @param toLp address of to LP token
    /// @param lpAmount Amount of from LP tokens to be used in one-tap
    /// @return helper Contains all the amount and fees information during the one-tap
    function getOneTapAmount(ILP fromLp, ILP toLp, uint256 lpAmount) public view returns (OneTapHelper memory helper) {
        // Withdraw process
        (helper.withdrawAmount, helper.withdrawFees, helper.fromTreasuryFees) = getWithdrawAmount(fromLp, lpAmount, true);
        require(helper.withdrawAmount > helper.withdrawFees, "HIGH FEES");
        
        uint256 amountForSwap = helper.withdrawAmount - helper.withdrawFees;
        // Update asset and liability of from token
        helper.fromAsset = fromLp.asset() - amountForSwap - helper.fromTreasuryFees;
        helper.fromLiability = fromLp.liability() - helper.withdrawAmount;
        
        // Swap process
        (uint256 toAmount, , uint256 treasuryFees, ) = getSwapAmount(fromLp, toLp, amountForSwap, true, helper.fromAsset, helper.fromLiability);
        // Update asset of from token after swap
        helper.fromAsset += amountForSwap;
        // Update asset of to token after swap
        helper.toAsset = toLp.asset() - toAmount - treasuryFees;
        helper.toTreasuryFees = treasuryFees;

        // Deposit process
        (helper.depositLpAmount, helper.depositFees, treasuryFees) = getDepositAmount(toLp, toAmount, true, helper.toAsset);
        helper.toTreasuryFees += treasuryFees;
        // Update asset and liability of to token
        helper.toAsset += toAmount - treasuryFees;
        helper.toLiability = toLp.liability() + (toAmount - helper.depositFees);

        uint256 toLiquidityRatio = helper.toAsset * ONE_18 / helper.toLiability;
        require(toLiquidityRatio > 1e18, "To lr < 1");
        require(helper.fromAsset * ONE_18 / helper.fromLiability < toLiquidityRatio, "From lr > to lr");
    }

    function tokenOraclePrice(address _address) public view returns (uint256) {
        AggregatorV3Interface feed = AggregatorV3Interface(priceFeeds[_address]);
        ( , int price, , , ) = feed.latestRoundData();
        return uint(price) * ONE_18 / (10 ** feed.decimals());
    }
}