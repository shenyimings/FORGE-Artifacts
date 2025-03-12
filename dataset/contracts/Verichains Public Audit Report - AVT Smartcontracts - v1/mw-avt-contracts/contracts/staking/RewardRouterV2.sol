// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../libraries/math/SafeMath.sol";
import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";
import "../libraries/utils/Address.sol";
import "./interfaces/IRewardTracker.sol";
import "./interfaces/IAlpReferralReward.sol";
import "../tokens/interfaces/IWETH.sol";
import "../core/interfaces/IAlpManager.sol";
import "../access/Governable.sol";

contract RewardRouterV2 is ReentrancyGuard, Governable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;

    bool public isInitialized;

    address public weth;

    address public avt;

    address public alp; // AVT Liquidity Provider token

    address public stakedAvtTracker;
    address public feeAvtTracker;

    address public stakedAlpTracker;
    address public stakedAlpTracker2;
    address public feeAlpTracker;
    address public alpReferralReward;

    address public alpManager;

    bool public stakedAlpEnable = true;

    mapping(address => address) public pendingReceivers;

    event StakeAvt(address account, address token, uint256 amount);
    event UnstakeAvt(address account, address token, uint256 amount);

    event StakeAlp(address account, uint256 amount);
    event UnstakeAlp(address account, uint256 amount);

    receive() external payable {
        require(msg.sender == weth, "Router: invalid sender");
    }

    function initialize(
        address _weth,
        address _avt,
        address _alp,
        address _stakedAvtTracker,
        address _feeAvtTracker,
        address _feeAlpTracker,
        address _stakedAlpTracker,
        address _stakedAlpTracker2,
        address _alpReferralReward,
        address _alpManager
    ) external onlyGov {
        require(!isInitialized, "RewardRouter: already initialized");
        isInitialized = true;

        weth = _weth;

        avt = _avt;

        alp = _alp;

        stakedAvtTracker = _stakedAvtTracker;
        feeAvtTracker = _feeAvtTracker;

        feeAlpTracker = _feeAlpTracker;
        stakedAlpTracker = _stakedAlpTracker;
        stakedAlpTracker2 = _stakedAlpTracker2;
        alpReferralReward = _alpReferralReward;

        alpManager = _alpManager;
    }

    function setStakedAlpEnable(bool _stakedAlpEnable) external onlyGov {
        stakedAlpEnable = _stakedAlpEnable;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function batchStakeAvtForAccount(
        address[] memory _accounts,
        uint256[] memory _amounts
    ) external nonReentrant onlyGov {
        address _avt = avt;
        for (uint256 i = 0; i < _accounts.length; i++) {
            _stakeAvt(msg.sender, _accounts[i], _avt, _amounts[i]);
        }
    }

    function stakeAvtForAccount(address _account, uint256 _amount) external nonReentrant onlyGov {
        _stakeAvt(msg.sender, _account, avt, _amount);
    }

    function stakeAvt(uint256 _amount) external nonReentrant {
        _stakeAvt(msg.sender, msg.sender, avt, _amount);
    }

    function unstakeAvt(uint256 _amount) external nonReentrant {
        _unstakeAvt(msg.sender, avt, _amount);
    }

    function mintAndStakeAlp(
        address _token,
        uint256 _amount,
        uint256 _minUsdg,
        uint256 _minAlp
    ) external nonReentrant returns (uint256) {
        require(_amount > 0, "RewardRouter: invalid _amount");

        address account = msg.sender;

        uint256 alpAmount = IAlpManager(alpManager).addLiquidityForAccount(
            account,
            account,
            _token,
            _amount,
            _minUsdg,
            _minAlp
        );
        IRewardTracker(feeAlpTracker).stakeForAccount(account, account, alp, alpAmount);

        if (stakedAlpEnable) {
            IRewardTracker(stakedAlpTracker).stakeForAccount(account, account, feeAlpTracker, alpAmount);
            IRewardTracker(stakedAlpTracker2).stakeForAccount(account, account, stakedAlpTracker, alpAmount);
        }

        emit StakeAlp(account, alpAmount);

        return alpAmount;
    }

    function mintAndStakeAlpETH(uint256 _minUsdg, uint256 _minAlp) external payable nonReentrant returns (uint256) {
        require(msg.value > 0, "RewardRouter: invalid msg.value");

        IWETH(weth).deposit{ value: msg.value }();
        IERC20(weth).approve(alpManager, msg.value);

        address account = msg.sender;

        uint256 alpAmount = IAlpManager(alpManager).addLiquidityForAccount(
            address(this),
            account,
            weth,
            msg.value,
            _minUsdg,
            _minAlp
        );

        IRewardTracker(feeAlpTracker).stakeForAccount(account, account, alp, alpAmount);

        if (stakedAlpEnable) {
            IRewardTracker(stakedAlpTracker).stakeForAccount(account, account, feeAlpTracker, alpAmount);
            IRewardTracker(stakedAlpTracker2).stakeForAccount(account, account, stakedAlpTracker, alpAmount);
        }

        emit StakeAlp(account, alpAmount);

        return alpAmount;
    }

    function unstakeAndRedeemAlp(
        address _tokenOut,
        uint256 _alpAmount,
        uint256 _minOut,
        address _receiver
    ) external nonReentrant returns (uint256) {
        require(_alpAmount > 0, "RewardRouter: invalid _alpAmount");

        address account = msg.sender;
        uint256 stakedAlpBalance = IERC20(stakedAlpTracker2).balanceOf(account);
        if (stakedAlpBalance != 0) {
            uint256 stakedAlpAmount = stakedAlpBalance > _alpAmount ? _alpAmount : stakedAlpBalance;
            IRewardTracker(stakedAlpTracker2).unstakeForAccount(account, stakedAlpTracker, stakedAlpAmount, account);
            IRewardTracker(stakedAlpTracker).unstakeForAccount(account, feeAlpTracker, stakedAlpAmount, account);
        }

        IRewardTracker(feeAlpTracker).unstakeForAccount(account, alp, _alpAmount, account);
        uint256 amountOut = IAlpManager(alpManager).removeLiquidityForAccount(
            account,
            _tokenOut,
            _alpAmount,
            _minOut,
            _receiver
        );

        emit UnstakeAlp(account, _alpAmount);

        return amountOut;
    }

    function unstakeAndRedeemAlpETH(
        uint256 _alpAmount,
        uint256 _minOut,
        address payable _receiver
    ) external nonReentrant returns (uint256) {
        require(_alpAmount > 0, "RewardRouter: invalid _alpAmount");

        address account = msg.sender;
        uint256 stakedAlpBalance = IERC20(stakedAlpTracker2).balanceOf(account);
        if (stakedAlpBalance != 0) {
            uint256 stakedAlpAmount = stakedAlpBalance > _alpAmount ? _alpAmount : stakedAlpBalance;
            IRewardTracker(stakedAlpTracker2).unstakeForAccount(account, stakedAlpTracker, stakedAlpAmount, account);
            IRewardTracker(stakedAlpTracker).unstakeForAccount(account, feeAlpTracker, stakedAlpAmount, account);
        }
        IRewardTracker(feeAlpTracker).unstakeForAccount(account, alp, _alpAmount, account);
        uint256 amountOut = IAlpManager(alpManager).removeLiquidityForAccount(
            account,
            weth,
            _alpAmount,
            _minOut,
            address(this)
        );

        IWETH(weth).withdraw(amountOut);

        _receiver.sendValue(amountOut);

        emit UnstakeAlp(account, _alpAmount);

        return amountOut;
    }

    function claim() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(feeAvtTracker).claimForAccount(account, account);
        IRewardTracker(feeAlpTracker).claimForAccount(account, account);

        IRewardTracker(stakedAvtTracker).claimForAccount(account, account);
        uint256 baseAmount = IRewardTracker(stakedAlpTracker).claimForAccount(account, account);
        baseAmount = baseAmount.add(IRewardTracker(stakedAlpTracker2).claimForAccount(account, account));

        IAlpReferralReward(alpReferralReward).increaseAlpReferral(account, baseAmount);
    }

    function claimAvt() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(stakedAvtTracker).claimForAccount(account, account);
        uint256 baseAmount = IRewardTracker(stakedAlpTracker).claimForAccount(account, account);
        baseAmount = baseAmount.add(IRewardTracker(stakedAlpTracker2).claimForAccount(account, account));

        IAlpReferralReward(alpReferralReward).increaseAlpReferral(account, baseAmount);
    }

    function claimFees() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(feeAvtTracker).claimForAccount(account, account);
        IRewardTracker(feeAlpTracker).claimForAccount(account, account);
    }

    function compound() external nonReentrant {
        _compound(msg.sender);
    }

    function compoundForAccount(address _account) external nonReentrant onlyGov {
        _compound(_account);
    }

    function handleRewards(
        bool _shouldClaimStakedAvtReward,
        bool _shouldClaimStakedAlpReward,
        bool _shouldClaimAlpReferralReward,
        bool _shouldStakeAvt,
        bool _shouldClaimWeth,
        bool _shouldConvertWethToEth
    ) external nonReentrant {
        address account = msg.sender;

        uint256 avtAmount = 0;
        if (_shouldClaimStakedAvtReward) {
            avtAmount = IRewardTracker(stakedAvtTracker).claimForAccount(account, account);
        }
        if (_shouldClaimStakedAlpReward) {
            uint256 avtAmount1 = IRewardTracker(stakedAlpTracker).claimForAccount(account, account);
            uint256 avtAmount2 = IRewardTracker(stakedAlpTracker2).claimForAccount(account, account);
            avtAmount = avtAmount.add(avtAmount1).add(avtAmount2);

            IAlpReferralReward(alpReferralReward).increaseAlpReferral(account, avtAmount);
        }

        if (_shouldClaimAlpReferralReward) {
            avtAmount = avtAmount.add(IAlpReferralReward(alpReferralReward).claimForReferrer(account));
        }

        if (_shouldStakeAvt && avtAmount > 0) {
            _stakeAvt(account, account, avt, avtAmount);
        }

        if (_shouldClaimWeth) {
            if (_shouldConvertWethToEth) {
                uint256 weth0 = IRewardTracker(feeAvtTracker).claimForAccount(account, address(this));
                uint256 weth1 = IRewardTracker(feeAlpTracker).claimForAccount(account, address(this));

                uint256 wethAmount = weth0.add(weth1);
                IWETH(weth).withdraw(wethAmount);

                payable(account).sendValue(wethAmount);
            } else {
                IRewardTracker(feeAvtTracker).claimForAccount(account, account);
                IRewardTracker(feeAlpTracker).claimForAccount(account, account);
            }
        }
    }

    function batchCompoundForAccounts(address[] memory _accounts) external nonReentrant onlyGov {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _compound(_accounts[i]);
        }
    }

    function _compound(address _account) private {
        _compoundAvt(_account);
        _compoundAlp(_account);
    }

    function _compoundAvt(address _account) private {
        uint256 avtAmount = IRewardTracker(stakedAvtTracker).claimForAccount(_account, _account);
        if (avtAmount > 0) {
            _stakeAvt(_account, _account, avt, avtAmount);
        }
    }

    function _compoundAlp(address _account) private {
        uint256 avtAmount = IRewardTracker(stakedAlpTracker).claimForAccount(_account, _account);
        avtAmount = avtAmount.add(IRewardTracker(stakedAlpTracker2).claimForAccount(_account, _account));
        if (avtAmount > 0) {
            IAlpReferralReward(alpReferralReward).increaseAlpReferral(_account, avtAmount);
            _stakeAvt(_account, _account, avt, avtAmount);
        }
    }

    function _stakeAvt(address _fundingAccount, address _account, address _token, uint256 _amount) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        IRewardTracker(feeAvtTracker).stakeForAccount(_fundingAccount, _account, _token, _amount);
        IRewardTracker(stakedAvtTracker).stakeForAccount(_account, _account, feeAvtTracker, _amount);

        emit StakeAvt(_account, _token, _amount);
    }

    function _unstakeAvt(address _account, address _token, uint256 _amount) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        IRewardTracker(stakedAvtTracker).unstakeForAccount(_account, feeAvtTracker, _amount, _account);
        IRewardTracker(feeAvtTracker).unstakeForAccount(_account, _token, _amount, _account);

        emit UnstakeAvt(_account, _token, _amount);
    }
}
