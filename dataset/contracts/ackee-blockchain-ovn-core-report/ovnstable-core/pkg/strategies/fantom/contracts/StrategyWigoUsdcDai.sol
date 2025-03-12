// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./core/Strategy.sol";
import "./exchanges/BeethovenxExchange.sol";
import "./libraries/LowGasSafeMath.sol";
import "./connectors/uniswap/v2/interfaces/IUniswapV2Router02.sol";
import "./connectors/uniswap/v2/interfaces/IUniswapV2Pair.sol";
import "./connectors/tarot/interfaces/IBorrowable.sol";
import "./connectors/wigo/AWigoMasterFarmer.sol";

contract StrategyWigoUsdcDai is Strategy, BeethovenExchange {
    using LowGasSafeMath for uint256;

    IERC20 public daiToken;
    IERC20 public usdcToken;
    IERC20 public wigoToken;

    uint256 public bUsdcTokenDenominator;
    uint256 public bDaiTokenDenominator;

    IUniswapV2Router02 public router;
    IUniswapV2Pair public lpToken;
    AWigoMasterFarmer public masterFarmer;
    uint256 public pid;
    bytes32 public poolIdDaiUsdc;


    // --- events

    event StrategyUpdatedTokens(
        address daiToken, address usdcToken, address wigoToken, 
        uint256 bUsdcTokenDenominator, uint256 bDaiTokenDenominator
    );

    event StrategyUpdatedParams(address router, address lpToken, address masterFarmer, uint256 pid,
        address beethovenxVault, bytes32 poolIdDaiUsdc);


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- setters

    function setTokens(
        address _daiToken,
        address _usdcToken,
        address _wigoToken
    ) external onlyAdmin {

        require(_daiToken != address(0), "Zero address not allowed");
        require(_usdcToken != address(0), "Zero address not allowed");
        require(_wigoToken != address(0), "Zero address not allowed");

        daiToken = IERC20(_daiToken);
        usdcToken = IERC20(_usdcToken);
        wigoToken = IERC20(_wigoToken);

        bUsdcTokenDenominator = 10 ** IERC20Metadata(_usdcToken).decimals();
        bDaiTokenDenominator = 10 ** IERC20Metadata(_daiToken).decimals();

        emit StrategyUpdatedTokens(_daiToken, _usdcToken, _wigoToken, bUsdcTokenDenominator, bDaiTokenDenominator);
    }

    function setParams(
        address _router,
        address _lpToken,
        address _masterFarmer,
        uint256 _pid,
        address _beethovenxVault,
        bytes32 _poolIdDaiUsdc
    ) external onlyAdmin {

        require(_router != address(0), "Zero address not allowed");
        require(_lpToken != address(0), "Zero address not allowed");
        require(_masterFarmer != address(0), "Zero address not allowed");
        require(_beethovenxVault != address(0), "Zero address not allowed");
        require(_poolIdDaiUsdc != "", "Empty pool id not allowed");

        router = IUniswapV2Router02(_router);
        lpToken = IUniswapV2Pair(_lpToken);
        masterFarmer = AWigoMasterFarmer(_masterFarmer);
        pid = _pid;
        poolIdDaiUsdc = _poolIdDaiUsdc;

        setBeethovenxVault(_beethovenxVault);

        emit StrategyUpdatedParams(_router, _lpToken, _masterFarmer, _pid, _beethovenxVault, _poolIdDaiUsdc);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");
        (uint256 reserveUsdc, uint256 reserveDai,) = lpToken.getReserves();
        require(
            reserveUsdc > bUsdcTokenDenominator / 1000 && reserveDai > bDaiTokenDenominator / 1000, 
            'StrategyWigoUsdcDai: Liquidity lpToken reserves too low'
        );

        // swap needed usdс to dai
        uint256 amountUsdcToSwap = _getAmountUsdcToSwap(_amount, reserveUsdc, reserveDai, bDaiTokenDenominator / bUsdcTokenDenominator);
        swap(
            poolIdDaiUsdc,
            IVault.SwapKind.GIVEN_IN,
            IAsset(address(usdcToken)),
            IAsset(address(daiToken)),
            address(this),
            address(this),
            amountUsdcToSwap,
            0
        );

        // add liquidity
        uint256 amountUsdc = usdcToken.balanceOf(address(this));
        uint256 amountDai = daiToken.balanceOf(address(this));

        usdcToken.approve(address(router), amountUsdc);
        daiToken.approve(address(router), amountDai);
        router.addLiquidity(
            address(usdcToken),
            address(daiToken),
            amountUsdc,
            amountDai,
            amountUsdc * 99 / 100,
            amountDai * 99 / 100,
            address(this),
            block.timestamp + 600
        );
        
        // deposit lpTokens
        uint256 lpBalance = lpToken.balanceOf(address(this));
        lpToken.approve(address(masterFarmer), lpBalance);
        masterFarmer.deposit(pid, lpBalance);

        amountDai = daiToken.balanceOf(address(this));
        
        if (amountDai > 0) {
            swap(
                poolIdDaiUsdc,
                IVault.SwapKind.GIVEN_IN,
                IAsset(address(daiToken)),
                IAsset(address(usdcToken)),
                address(this),
                address(this),
                amountDai,
                0
            );
        }
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");
        
        (uint256 lpBalanceUser, ) = masterFarmer.userInfo(pid, address(this));
        if (lpBalanceUser == 0) {
            return 0;
        }

        // withdraw needed amount of lpTokens
        uint256 totalLpBalance = lpToken.totalSupply();
        (uint256 reserveUsdc, uint256 reserveDai,) = lpToken.getReserves();
        uint256 lpBalance = _getAmountLPTokensForWithdraw(
            _amount, reserveUsdc, reserveDai, totalLpBalance, bDaiTokenDenominator / bUsdcTokenDenominator);
        masterFarmer.withdraw(pid, lpBalance);

        // remove liquidity
        uint256 amountOutUsdcMin = reserveUsdc * lpBalance / totalLpBalance;
        uint256 amountOutDaiMin = reserveDai * lpBalance / totalLpBalance;
        lpToken.approve(address(router), lpBalance);
        router.removeLiquidity(
            lpToken.token0(),
            lpToken.token1(),
            lpBalance,
            amountOutUsdcMin * 99 / 100,
            amountOutDaiMin * 99 / 100,
            address(this),
            block.timestamp + 600
        );
        
    
        // swap dai to usdc
        uint256 daiBalance = daiToken.balanceOf(address(this));
        swap(
            poolIdDaiUsdc,
            IVault.SwapKind.GIVEN_IN,
            IAsset(address(daiToken)),
            IAsset(address(usdcToken)),
            address(this),
            address(this),
            daiBalance,
            0
        );

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        (uint256 lpBalanceUser, ) = masterFarmer.userInfo(pid, address(this));
        if (lpBalanceUser == 0) {
            return 0;
        }

        // withdraw lpTokens from masterFarmer
        masterFarmer.withdraw(pid, lpBalanceUser);

        // remove liquidity
        uint256 totalLpBalance = lpToken.totalSupply();
        (uint256 reserveUsdc, uint256 reserveDai,) = lpToken.getReserves();
        uint256 amountOutUsdcMin = reserveUsdc * lpBalanceUser / totalLpBalance;
        uint256 amountOutDaiMin = reserveDai * lpBalanceUser / totalLpBalance;
        lpToken.approve(address(router), lpBalanceUser);
        router.removeLiquidity(
            lpToken.token0(),
            lpToken.token1(),
            lpBalanceUser,
            amountOutUsdcMin * 99 / 100,
            amountOutDaiMin * 99 / 100,
            address(this),
            block.timestamp + 600
        );

        // swap dai to usdc
        uint256 daiBalance = daiToken.balanceOf(address(this));
        swap(
            poolIdDaiUsdc,
            IVault.SwapKind.GIVEN_IN,
            IAsset(address(daiToken)),
            IAsset(address(usdcToken)),
            address(this),
            address(this),
            daiBalance,
            0
        );

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue();
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue();
    }

    function _totalValue() internal view returns (uint256) {
        (uint256 lpBalance, ) = masterFarmer.userInfo(pid, address(this));
        if (lpBalance == 0) {
            return 0;
        }
        uint256 totalLpBalance = lpToken.totalSupply();
        (uint256 reserveUsdc, uint256 reserveDai,) = lpToken.getReserves();
        uint256 usdcBalance = reserveUsdc * lpBalance / totalLpBalance + usdcToken.balanceOf(address(this));
        uint256 daiBalance = reserveDai * lpBalance / totalLpBalance + daiToken.balanceOf(address(this));

        uint256 usdcBalanceFromDai = onSwap(
            poolIdDaiUsdc,
            IVault.SwapKind.GIVEN_IN,
            daiToken,
            usdcToken,
            daiBalance
        );

        return usdcBalance + usdcBalanceFromDai;
    }

    function _claimRewards(address _to) internal override returns (uint256) {
        // claim rewards
        masterFarmer.withdraw(pid, 0);

        // sell rewards
        uint256 totalUsdc;
        uint256 wigoBalance = wigoToken.balanceOf(address(this));

        if (wigoBalance != 0) {
            uint256 wigoUsdc = _swapWigoToUsdc(wigoBalance);
            totalUsdc += wigoUsdc;
        }

        usdcToken.transfer(_to, usdcToken.balanceOf(address(this)));
        return totalUsdc;
    }

    function _swapWigoToUsdc(uint256 wigoBalance) internal returns (uint256) {
        wigoToken.approve(address(router), wigoBalance);

        address[] memory path = new address[](2);
        path[0] = address(wigoToken);
        path[1] = address(usdcToken);

        uint256[] memory amounts = router.swapExactTokensForTokens(
                wigoBalance,
                0,
                path,
                address(this),
                block.timestamp + 600
            );

        return amounts[1];
    }

    function _getAmountUsdcToSwap(
        uint256 amount,
        uint256 reserveUsdc,
        uint256 reserveDai,
        uint256 decimalDelta
    ) internal view returns (uint256) {
        uint256 amountUsdcToSwap = (amount * reserveDai) / (reserveDai + reserveUsdc * decimalDelta);
        for (uint i=0; i<2; i++) {
            uint256 swappedDai = onSwap(
                poolIdDaiUsdc,
                IVault.SwapKind.GIVEN_IN,
                usdcToken,
                daiToken,
                amountUsdcToSwap
            );
            amountUsdcToSwap = (amount * reserveDai * amountUsdcToSwap) / (reserveDai * amountUsdcToSwap + reserveUsdc * swappedDai);
        }
        return amountUsdcToSwap;
    }

    function _getAmountLPTokensForWithdraw(
        uint256 amount,
        uint256 reserveUsdc,
        uint256 reserveDai,
        uint256 totalLpBalance,
        uint256 decimalDelta
    ) internal view returns (uint256) {
        uint256 lpBalance;
        uint256 amountDaiToSwap = decimalDelta;
        uint256 swappedUsdc = 1;
        for (uint i=0; i<2; i++) {
            lpBalance = (totalLpBalance * amountDaiToSwap * amount) / (reserveDai * swappedUsdc + reserveUsdc * amountDaiToSwap);
            amountDaiToSwap = (reserveDai * lpBalance) / totalLpBalance;
            swappedUsdc = onSwap(
                poolIdDaiUsdc,
                IVault.SwapKind.GIVEN_IN,
                daiToken,
                usdcToken,
                amountDaiToSwap
            );
        }
        lpBalance = (totalLpBalance * amountDaiToSwap * amount) / (reserveDai * swappedUsdc + reserveUsdc * amountDaiToSwap);
        return lpBalance;
    }
}