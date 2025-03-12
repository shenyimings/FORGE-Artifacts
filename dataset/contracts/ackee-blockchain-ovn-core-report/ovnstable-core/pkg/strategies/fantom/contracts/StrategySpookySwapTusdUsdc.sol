// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./core/Strategy.sol";
import "./exchanges/BeethovenxExchange.sol";
import "./libraries/LowGasSafeMath.sol";
import "./connectors/uniswap/v2/interfaces/IUniswapV2Router02.sol";
import "./connectors/uniswap/v2/interfaces/IUniswapV2Pair.sol";
import "./connectors/spookyswap/ASpookySwapMasterChef.sol";


contract StrategySpookySwapTusdUsdc is Strategy, BeethovenExchange {
    using LowGasSafeMath for uint256;

    IERC20 public tusdToken;
    IERC20 public usdcToken;
    IERC20 public booToken;

    IUniswapV2Router02 public router;
    IUniswapV2Pair public lpToken;
    ASpookySwapMasterChef public masterChef;
    uint256 public pid;
    bytes32 public poolIdTusdUsdc;
    bytes32 public poolIdBooUsdc;


    // --- events

    event StrategyUpdatedTokens(address tusdToken, address usdcToken, address booToken);

    event StrategyUpdatedParams(address router, address lpToken, address masterChef, uint256 pid,
        address beethovenxVault, bytes32 poolIdTusdUsdc, bytes32 poolIdBooUsdc);


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- setters

    function setTokens(
        address _tusdToken,
        address _usdcToken,
        address _booToken
    ) external onlyAdmin {

        require(_tusdToken != address(0), "Zero address not allowed");
        require(_usdcToken != address(0), "Zero address not allowed");
        require(_booToken != address(0), "Zero address not allowed");

        tusdToken = IERC20(_tusdToken);
        usdcToken = IERC20(_usdcToken);
        booToken = IERC20(_booToken);

        emit StrategyUpdatedTokens(_tusdToken, _usdcToken, _booToken);
    }

    function setParams(
        address _router,
        address _lpToken,
        address _masterChef,
        uint256 _pid,
        address _beethovenxVault,
        bytes32 _poolIdTusdUsdc,
        bytes32 _poolIdBooUsdc
    ) external onlyAdmin {

        require(_router != address(0), "Zero address not allowed");
        require(_lpToken != address(0), "Zero address not allowed");
        require(_masterChef != address(0), "Zero address not allowed");
        require(_beethovenxVault != address(0), "Zero address not allowed");
        require(_poolIdTusdUsdc != "", "Empty pool id not allowed");
        require(_poolIdBooUsdc != "", "Empty pool id not allowed");

        router = IUniswapV2Router02(_router);
        lpToken = IUniswapV2Pair(_lpToken);
        masterChef = ASpookySwapMasterChef(_masterChef);
        pid = _pid;
        poolIdTusdUsdc = _poolIdTusdUsdc;
        poolIdBooUsdc = _poolIdBooUsdc;

        setBeethovenxVault(_beethovenxVault);

        emit StrategyUpdatedParams(_router, _lpToken, _masterChef, _pid, _beethovenxVault, _poolIdTusdUsdc, _poolIdBooUsdc);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        (uint256 reserveUsdc, uint256 reserveTusd,) = lpToken.getReserves();
        require(reserveUsdc > 10 ** 3 && reserveTusd > 10 ** 15, 'StrategySpookySwapTusdUsdc: Liquidity lpToken reserves too low');

        // count amount tusd to swap
        uint256 tusdBalance = tusdToken.balanceOf(address(this));
        uint256 amountUsdcFromTusd;
        if (tusdBalance > 0) {
            amountUsdcFromTusd = onSwap(
                poolIdTusdUsdc,
                IVault.SwapKind.GIVEN_IN,
                tusdToken,
                usdcToken,
                tusdBalance
            );
        }
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 amountUsdcToSwap = _getAmountUsdcToSwap(usdcBalance - amountUsdcFromTusd, reserveUsdc, reserveTusd);

        // swap usdc to tusd
        swap(
            poolIdTusdUsdc,
            IVault.SwapKind.GIVEN_IN,
            IAsset(address(usdcToken)),
            IAsset(address(tusdToken)),
            address(this),
            address(this),
            amountUsdcToSwap,
            0
        );

        // add liquidity
        usdcBalance = usdcToken.balanceOf(address(this));
        tusdBalance = tusdToken.balanceOf(address(this));
        usdcToken.approve(address(router), usdcBalance);
        tusdToken.approve(address(router), tusdBalance);
        router.addLiquidity(
            address(usdcToken),
            address(tusdToken),
            usdcBalance,
            tusdBalance,
            usdcBalance * 99 / 100,
            tusdBalance * 99 / 100,
            address(this),
            block.timestamp + 600
        );

        // deposit lpTokens to masterChef
        uint256 lpBalance = lpToken.balanceOf(address(this));
        lpToken.approve(address(masterChef), lpBalance);
        masterChef.deposit(pid, lpBalance);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        (uint256 reserveUsdc, uint256 reserveTusd,) = lpToken.getReserves();
        require(reserveUsdc > 10 ** 3 && reserveTusd > 10 ** 15, 'StrategySpookySwapTusdUsdc: Liquidity lpToken reserves too low');

        (uint256 lpBalanceUser, ) = masterChef.userInfo(pid, address(this));
        if (lpBalanceUser > 0) {
            // count amount to unstake
            uint256 totalLpBalance = lpToken.totalSupply();
            uint256 lpBalance = _getAmountLPTokensForWithdraw(_amount, reserveUsdc, reserveTusd, totalLpBalance);
            if (lpBalance > lpBalanceUser) {
                lpBalance = lpBalanceUser;
            }

            // withdraw lpTokens from masterChef
            masterChef.withdraw(pid, lpBalance);

            // remove liquidity
            uint256 amountOutUsdcMin = reserveUsdc * lpBalance / totalLpBalance;
            uint256 amountOutTusdMin = reserveTusd * lpBalance / totalLpBalance;
            lpToken.approve(address(router), lpBalance);
            router.removeLiquidity(
                lpToken.token0(),
                lpToken.token1(),
                lpBalance,
                amountOutUsdcMin * 99 / 100,
                amountOutTusdMin * 99 / 100,
                address(this),
                block.timestamp + 600
            );
        }

        // swap tusd to usdc
        uint256 tusdBalance = tusdToken.balanceOf(address(this));
        if (tusdBalance > 10 ** 12) {
            swap(
                poolIdTusdUsdc,
                IVault.SwapKind.GIVEN_IN,
                IAsset(address(tusdToken)),
                IAsset(address(usdcToken)),
                address(this),
                address(this),
                tusdBalance,
                0
            );
        }

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        (uint256 lpBalanceUser, ) = masterChef.userInfo(pid, address(this));
        if (lpBalanceUser > 0) {
            // withdraw lpTokens from masterChef
            masterChef.withdraw(pid, lpBalanceUser);

            // remove liquidity
            (uint256 reserveUsdc, uint256 reserveTusd,) = lpToken.getReserves();
            uint256 totalLpBalance = lpToken.totalSupply();
            uint256 amountOutUsdcMin = reserveUsdc * lpBalanceUser / totalLpBalance;
            uint256 amountOutTusdMin = reserveTusd * lpBalanceUser / totalLpBalance;
            
            lpToken.approve(address(router), lpBalanceUser);
            router.removeLiquidity(
                lpToken.token0(),
                lpToken.token1(),
                lpBalanceUser,
                amountOutUsdcMin * 99 / 100,
                amountOutTusdMin * 99 / 100,
                address(this),
                block.timestamp + 600
            );
        }

        // swap tusd to usdc
        uint256 tusdBalance = tusdToken.balanceOf(address(this));
        if (tusdBalance > 0) {
            swap(
                poolIdTusdUsdc,
                IVault.SwapKind.GIVEN_IN,
                IAsset(address(tusdToken)),
                IAsset(address(usdcToken)),
                address(this),
                address(this),
                tusdBalance,
                0
            );
        }

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue();
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue();
    }

    function _totalValue() internal view returns (uint256) {
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 tusdBalance = tusdToken.balanceOf(address(this));

        (uint256 lpBalance, ) = masterChef.userInfo(pid, address(this));
        if (lpBalance > 0) {
            uint256 totalLpBalance = lpToken.totalSupply();
            (uint256 reserveUsdc, uint256 reserveTusd,) = lpToken.getReserves();
            usdcBalance += reserveUsdc * lpBalance / totalLpBalance;
            tusdBalance += reserveTusd * lpBalance / totalLpBalance;
        }

        uint256 usdcBalanceFromTusd;
        if (tusdBalance > 0) {
            usdcBalanceFromTusd = onSwap(
                poolIdTusdUsdc,
                IVault.SwapKind.GIVEN_IN,
                tusdToken,
                usdcToken,
                tusdBalance
            );
        }

        return usdcBalance + usdcBalanceFromTusd;
    }

    function _claimRewards(address _to) internal override returns (uint256) {
        // claim rewards
        (uint256 lpBalance, ) = masterChef.userInfo(pid, address(this));
        if (lpBalance > 0) {
            masterChef.withdraw(pid, 0);
        }

        // sell rewards
        uint256 totalUsdc;

        uint256 booBalance = booToken.balanceOf(address(this));
        if (booBalance > 0) {
            uint256 booUsdc = swap(
                poolIdBooUsdc,
                IVault.SwapKind.GIVEN_IN,
                IAsset(address(booToken)),
                IAsset(address(usdcToken)),
                address(this),
                address(this),
                booBalance,
                0
            );
            totalUsdc += booUsdc;
        }

        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        if (usdcBalance > 0) {
            usdcToken.transfer(_to, usdcBalance);
        }

        return totalUsdc;
    }

    function _getAmountUsdcToSwap(
        uint256 amount,
        uint256 reserveUsdc,
        uint256 reserveTusd
    ) internal view returns (uint256) {
        uint256 USDCtoTUSD = 1000000000000;
        uint256 amountUsdcToSwap = (amount * reserveTusd) / (reserveTusd + reserveUsdc * USDCtoTUSD);
        for (uint i = 0; i < 1; i++) {
            uint256 ons = onSwap(
                poolIdTusdUsdc,
                IVault.SwapKind.GIVEN_IN,
                usdcToken,
                tusdToken,
                amountUsdcToSwap
            );
            USDCtoTUSD = ons / amountUsdcToSwap;
            amountUsdcToSwap = (amount * reserveTusd) / (reserveTusd + reserveUsdc * USDCtoTUSD);
        }
        return amountUsdcToSwap;
    }

    function _getAmountLPTokensForWithdraw(
        uint256 amount,
        uint256 reserveUsdc,
        uint256 reserveTusd,
        uint256 totalLpBalance
    ) internal view returns (uint256) {
        uint256 TUSDtoUSDC = 1000000000000;
        uint256 lpBalance = (totalLpBalance * TUSDtoUSDC * amount) / (reserveTusd + reserveUsdc * TUSDtoUSDC);
        for (uint i = 0; i < 1; i++) {
            uint256 rdd = reserveTusd * lpBalance / totalLpBalance;
            uint256 ons = onSwap(
                poolIdTusdUsdc,
                IVault.SwapKind.GIVEN_IN,
                tusdToken,
                usdcToken,
                rdd
            );
            TUSDtoUSDC = rdd / ons;
            lpBalance = (totalLpBalance * TUSDtoUSDC * amount) / (reserveTusd + reserveUsdc * TUSDtoUSDC);
        }
        return lpBalance;
    }
}
