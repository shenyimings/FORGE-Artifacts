pragma solidity 0.6.12;

import "./interfaces/IERC20.sol";
import "./libraries/SafeERC20.sol";

import "./helpers/ReentrancyGuard.sol";
import "./helpers/Pausable.sol";
import "./helpers/Ownable.sol";

import "./interfaces/IXswapFarm.sol";
import "./interfaces/IXRouter01.sol";
import "./interfaces/IXRouter02.sol";

interface IWFTM is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

abstract contract StrategyDevil is Ownable, ReentrancyGuard, Pausable {
    // Maximises yields in e.g. pancakeswap

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bool public isSingleVault;
    bool public isAutoComp;

    address public farmContractAddress; // address of farm, eg, PCS, Thugs etc.
    uint256 public pid; // pid of pool in farmContractAddress
    address public wantAddress;
    address public token0Address;
    address public token1Address;
    address public earnedAddress;
    address public uniRouterAddress; // uniswap, pancakeswap etc
    address public buybackRouterAddress; // uniswap, pancakeswap etc
    uint256 public routerDeadlineDuration = 300;  // Set on global level, could be passed to functions via arguments

    address public wftmAddress;
    address public nativeFarmAddress;
    address public NATIVEAddress;
    address public govAddress; // timelock contract

    uint256 public lastEarnBlock = 0;
    uint256 public wantLockedTotal = 0;
    uint256 public sharesTotal = 0;

    uint256 public controllerFee = 200;
    uint256 public constant controllerFeeMax = 10000; // 100 = 1%
    uint256 public constant controllerFeeUL = 1000;

    uint256 public buyBackRate = 0;
    uint256 public constant buyBackRateMax = 10000; // 100 = 1%
    uint256 public constant buyBackRateUL = 1000;
    address public constant buyBackAddress = 0x000000000000000000000000000000000000dEaD;
    
    uint256 public entranceFeeFactor; // < 0.1% entrance fee - goes to pool + prevents front-running
    uint256 public constant entranceFeeFactorMax = 10000;
    uint256 public constant entranceFeeFactorLL = 9950; // 0.5% is the max entrance fee settable. LL = lowerlimit

    uint256 public depositFeeFactor; // 9600 == 4% fee
    uint256 public constant depositFeeFactorMax = 10000; // 100 = 1%
    uint256 public constant depositFeeFactorLL = 9500;

    uint256 public withdrawFeeFactor;
    uint256 public constant withdrawFeeFactorMax = 10000;
    uint256 public constant withdrawFeeFactorLL = 9500;

    uint256 public slippageFactor = 950; // 5% default slippage tolerance
    uint256 public constant slippageFactorUL = 995;

    address[] public earnedToNATIVEPath;
    address[] public earnedToToken0Path;
    address[] public earnedToToken1Path;
    address[] public token0ToEarnedPath;
    address[] public token1ToEarnedPath;
    address[] public earnedToWFTMPath;
    address[] public WFTMToNATIVEPath;

    modifier onlyAllowGov() {
        require(msg.sender == govAddress, "Not authorised");
        _;
    }

    // Receives new deposits from user
    function deposit(address _userAddress, uint256 _wantAmt)
        public
        virtual
        onlyOwner
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        IERC20(wantAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );

        // If depositFee in set, than _wantAmt - depositFee
        if (depositFeeFactor < depositFeeFactorMax) {
            _wantAmt = _wantAmt.mul(depositFeeFactor).div(depositFeeFactorMax);
        }

        uint256 sharesAdded = _wantAmt;
        if (wantLockedTotal > 0 && sharesTotal > 0) {
            sharesAdded = _wantAmt
                .mul(sharesTotal)
                .mul(entranceFeeFactor)
                .div(wantLockedTotal)
                .div(entranceFeeFactorMax);
        }
        sharesTotal = sharesTotal.add(sharesAdded);

        if (isAutoComp) {
            _farm();
        } else {
            wantLockedTotal = wantLockedTotal.add(_wantAmt);
        }

        return sharesAdded;
    }

    function farm() public virtual nonReentrant {
        _farm();
    }

    function _farm() internal virtual {
        require(isAutoComp, "!isAutoComp");
        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));
        wantLockedTotal = wantLockedTotal.add(wantAmt);
        IERC20(wantAddress).safeIncreaseAllowance(farmContractAddress, wantAmt);

        IXswapFarm(farmContractAddress).deposit(pid, wantAmt);
    }

    function _unfarm(uint256 _wantAmt) internal virtual {
        IXswapFarm(farmContractAddress).withdraw(pid, _wantAmt);
    }

    function withdraw(address _userAddress, uint256 _wantAmt)
        public
        virtual
        onlyOwner
        nonReentrant
        returns (uint256)
    {
        require(_wantAmt > 0, "_wantAmt <= 0");

        uint256 sharesRemoved = _wantAmt.mul(sharesTotal).div(wantLockedTotal);
        if (sharesRemoved > sharesTotal) {
            sharesRemoved = sharesTotal;
        }
        sharesTotal = sharesTotal.sub(sharesRemoved);

        if (withdrawFeeFactor < withdrawFeeFactorMax) {
            _wantAmt = _wantAmt.mul(withdrawFeeFactor).div(withdrawFeeFactorMax);
        }

        if (isAutoComp) {
            _unfarm(_wantAmt);
        }

        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));
        if (_wantAmt > wantAmt) {
            _wantAmt = wantAmt;
        }

        if (wantLockedTotal < _wantAmt) {
            _wantAmt = wantLockedTotal;
        }
    
        wantLockedTotal = wantLockedTotal.sub(_wantAmt);

        IERC20(wantAddress).safeTransfer(nativeFarmAddress, _wantAmt);

        return sharesRemoved;
    }

    function _harvest() internal virtual {
        _unfarm(0);
    }

    // 1. Harvest farm tokens
    // 2. Converts farm tokens into want tokens
    // 3. Deposits want tokens
    function earn() public virtual nonReentrant whenNotPaused {
        require(isAutoComp, "!isAutoComp");

        // Harvest farm tokens
        _harvest();

        // Converts farm tokens into want tokens
        uint256 earnedAmt = IERC20(earnedAddress).balanceOf(address(this));

        earnedAmt = distributeFees(earnedAmt);
        earnedAmt = buyBack(earnedAmt);

        if (isSingleVault) {
            if (earnedAddress != wantAddress) {
                IERC20(earnedAddress).safeIncreaseAllowance(
                    uniRouterAddress,
                    earnedAmt
                );

                // Swap earned to want
                _safeSwap(
                    uniRouterAddress,
                    earnedAmt,
                    slippageFactor,
                    earnedToToken0Path,
                    address(this),
                    now + routerDeadlineDuration
                );
            }
            lastEarnBlock = block.number;
            _farm();
            return;
        }

        IERC20(earnedAddress).safeIncreaseAllowance(
            uniRouterAddress,
            earnedAmt
        );

        if (earnedAddress != token0Address) {
            // Swap half earned to token0
            _safeSwap(
                uniRouterAddress,
                earnedAmt.div(2),
                slippageFactor,
                earnedToToken0Path,
                address(this),
                now + routerDeadlineDuration
            );
        }

        if (earnedAddress != token1Address) {
            // Swap half earned to token1
            _safeSwap(
                uniRouterAddress,
                earnedAmt.div(2),
                slippageFactor,
                earnedToToken1Path,
                address(this),
                now + routerDeadlineDuration
            );
        }

        // Get want tokens, ie. add liquidity
        uint256 token0Amt = IERC20(token0Address).balanceOf(address(this));
        uint256 token1Amt = IERC20(token1Address).balanceOf(address(this));
        if (token0Amt > 0 && token1Amt > 0) {
            IERC20(token0Address).safeIncreaseAllowance(
                uniRouterAddress,
                token0Amt
            );
            IERC20(token1Address).safeIncreaseAllowance(
                uniRouterAddress,
                token1Amt
            );
            IXRouter02(uniRouterAddress).addLiquidity(
                token0Address,
                token1Address,
                token0Amt,
                token1Amt,
                0,
                0,
                address(this),
                now + routerDeadlineDuration
            );
        }

        lastEarnBlock = block.number;

        _farm();
    }

    function buyBack(uint256 _earnedAmt) internal virtual returns (uint256) {
        if (buyBackRate <= 0) {
            return _earnedAmt;
        }

        uint256 buyBackAmt = _earnedAmt.mul(buyBackRate).div(buyBackRateMax);

        if (uniRouterAddress != buybackRouterAddress) {
            // Example case: LP token on ApeSwap and NATIVE token on PancakeSwap

            if (earnedAddress != wftmAddress) {
                // First convert earn to wftm
                IERC20(earnedAddress).safeIncreaseAllowance(
                    uniRouterAddress,
                    buyBackAmt
                );

                IXRouter02(uniRouterAddress)
                    .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    buyBackAmt,
                    0,
                    earnedToWFTMPath,
                    address(this),
                    now + routerDeadlineDuration
                );
            }

            // convert all wftm to Native and burn them
            uint256 wftmAmt = IERC20(wftmAddress).balanceOf(address(this));
            if (wftmAmt > 0) {
                IERC20(wftmAddress).safeIncreaseAllowance(
                    buybackRouterAddress,
                    wftmAmt
                );

                IXRouter02(buybackRouterAddress)
                    .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    wftmAmt,
                    0,
                    WFTMToNATIVEPath,
                    buyBackAddress,
                    now + routerDeadlineDuration
                );
            }
        } else {
            IERC20(earnedAddress).safeIncreaseAllowance(
                uniRouterAddress,
                buyBackAmt
            );

            _safeSwap(
                uniRouterAddress,
                buyBackAmt,
                slippageFactor,
                earnedToNATIVEPath,
                buyBackAddress,
                now + routerDeadlineDuration
            );
        }

        return _earnedAmt.sub(buyBackAmt);
    }

    function distributeFees(uint256 _earnedAmt) internal virtual returns (uint256) {
        if (_earnedAmt > 0) {
            // Performance fee
            if (controllerFee > 0) {
                uint256 fee =
                    _earnedAmt.mul(controllerFee).div(controllerFeeMax);
                IERC20(earnedAddress).safeTransfer(govAddress, fee);
                _earnedAmt = _earnedAmt.sub(fee);
            }
        }

        return _earnedAmt;
    }

    function convertDustToEarned() public virtual whenNotPaused {
        require(isAutoComp, "!isAutoComp");
        require(!isSingleVault, "isSingleVault");

        // Converts dust tokens into earned tokens, which will be reinvested on the next earn().

        // Converts token0 dust (if any) to earned tokens
        uint256 token0Amt = IERC20(token0Address).balanceOf(address(this));
        if (token0Address != earnedAddress && token0Amt > 0) {
            IERC20(token0Address).safeIncreaseAllowance(
                uniRouterAddress,
                token0Amt
            );

            // Swap all dust tokens to earned tokens
            _safeSwap(
                uniRouterAddress,
                token0Amt,
                slippageFactor,
                token0ToEarnedPath,
                address(this),
                now + routerDeadlineDuration
            );
        }

        // Converts token1 dust (if any) to earned tokens
        uint256 token1Amt = IERC20(token1Address).balanceOf(address(this));
        if (token1Address != earnedAddress && token1Amt > 0) {
            IERC20(token1Address).safeIncreaseAllowance(
                uniRouterAddress,
                token1Amt
            );

            // Swap all dust tokens to earned tokens
            _safeSwap(
                uniRouterAddress,
                token1Amt,
                slippageFactor,
                token1ToEarnedPath,
                address(this),
                now + routerDeadlineDuration
            );
        }
    }

    function pause() public virtual onlyAllowGov {
        _pause();
    }

    function unpause() external virtual onlyAllowGov {
        _unpause();
    }

    function setEntranceFeeFactor(uint256 _entranceFeeFactor) public onlyAllowGov {
        require(_entranceFeeFactor > entranceFeeFactorLL, "!safe - too low");
        require(_entranceFeeFactor <= entranceFeeFactorMax, "!safe - too high");
        entranceFeeFactor = _entranceFeeFactor;
    }

    function setControllerFee(uint256 _controllerFee) public onlyAllowGov{
        require(_controllerFee <= controllerFeeUL, "too high");
        controllerFee = _controllerFee;
    }

    function setGov(address _govAddress) public virtual onlyAllowGov {
        govAddress = _govAddress;
    }

    function setDepositFeeFactor(uint256 _depositFeeFactor) public onlyAllowGov{
        require(_depositFeeFactor > depositFeeFactorLL, "!safe - too low");
        require(_depositFeeFactor <= depositFeeFactorMax, "!safe - too high");
        depositFeeFactor = _depositFeeFactor;
    }

    function setWithdrawFeeFactor(uint256 _withdrawFeeFactor) public onlyAllowGov {
        require(_withdrawFeeFactor > withdrawFeeFactorLL, "!safe - too low");
        require(_withdrawFeeFactor <= withdrawFeeFactorMax, "!safe - too high");
        withdrawFeeFactor = _withdrawFeeFactor;
    }

    function setbuyBackRate(uint256 _buyBackRate) public onlyAllowGov {
        require(buyBackRate <= buyBackRateUL, "too high");
        buyBackRate = _buyBackRate;
    }

    function setBuybackRouterAddress(address _buybackRouterAddress) public onlyAllowGov {
        buybackRouterAddress = _buybackRouterAddress;
    }

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) public virtual onlyAllowGov {
        require(_token != earnedAddress, "!safe");
        require(_token != wantAddress, "!safe");
        IERC20(_token).safeTransfer(_to, _amount);
    }

    function _wrapFTM() internal virtual onlyAllowGov {
        // FTM -> WFTM
        uint256 ftmBal = address(this).balance;
        if (ftmBal > 0) {
            IWFTM(wftmAddress).deposit{value: ftmBal}(); // FTM -> WFTM
        }
    }

    function _safeSwap(
        address _uniRouterAddress,
        uint256 _amountIn,
        uint256 _slippageFactor,
        address[] memory _path,
        address _to,
        uint256 _deadline
    ) internal virtual {
        uint256[] memory amounts =
            IXRouter02(_uniRouterAddress).getAmountsOut(_amountIn, _path);
        uint256 amountOut = amounts[amounts.length.sub(1)];

        IXRouter02(_uniRouterAddress)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amountIn,
            amountOut.mul(_slippageFactor).div(1000),
            _path,
            _to,
            _deadline
        );
    }
}