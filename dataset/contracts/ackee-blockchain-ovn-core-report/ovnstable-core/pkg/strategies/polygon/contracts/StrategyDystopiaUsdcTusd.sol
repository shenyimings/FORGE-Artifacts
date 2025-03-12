// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/swapper/contracts/ISwapper.sol";
import "@overnight-contracts/connectors/contracts/stuff/Dystopia.sol";
import "@overnight-contracts/connectors/contracts/stuff/Penrose.sol";
import "@overnight-contracts/connectors/contracts/stuff/Curve.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";

contract StrategyDystopiaUsdcTusd is Strategy, DystopiaExchange {

    uint256 public constant BASIS_POINTS_FOR_SLIPPAGE_EIGHT = 8;

    IERC20 public usdcToken;
    IERC20 public tusdToken;
    IERC20 public dystToken;
    IERC20 public wmaticToken;

    uint256 public usdcTokenDenominator;
    uint256 public tusdTokenDenominator;

    IDystopiaLP public gauge;
    IDystopiaLP public dystPair;

    IPriceFeed public oracleUsdc;
    IPriceFeed public oracleTusd;

    IERC20 public penToken;
    IUserProxy public userProxy;
    IPenLens public penLens;

    ISwapper public swapper;

    uint256 public stakeStep;

    address public curveStablePool;
    address public curveMetaPool;

    int128 public curveIndexUsdc;
    int128 public curveIndexTusd;


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _usdcToken,
        address _tusdToken,
        address _dystToken,
        address _wmaticToken,
        address _penToken,
        int128 _curveIndexUsdc,
        int128 _curveIndexTusd
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_tusdToken != address(0), "Zero address not allowed");
        require(_dystToken != address(0), "Zero address not allowed");
        require(_wmaticToken != address(0), "Zero address not allowed");
        require(_penToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        tusdToken = IERC20(_tusdToken);
        dystToken = IERC20(_dystToken);
        wmaticToken = IERC20(_wmaticToken);
        penToken = IERC20(_penToken);
        usdcTokenDenominator = 10 ** IERC20Metadata(_usdcToken).decimals();
        tusdTokenDenominator = 10 ** IERC20Metadata(_tusdToken).decimals();

        curveIndexUsdc = _curveIndexUsdc;
        curveIndexTusd = _curveIndexTusd;
    }

    function setParams(
        address _gauge,
        address _dystPair,
        address _dystRouter,
        address _oracleUsdc,
        address _oracleTusd,
        address _userProxy,
        address _penLens,
        address _swapper,
        uint256 _stakeStep,
        address _curveStablePool,
        address _curveMetaPool
    ) external onlyAdmin {

        require(_gauge != address(0), "Zero address not allowed");
        require(_dystPair != address(0), "Zero address not allowed");
        require(_dystRouter != address(0), "Zero address not allowed");
        require(_oracleUsdc != address(0), "Zero address not allowed");
        require(_oracleTusd != address(0), "Zero address not allowed");
        require(_userProxy != address(0), "Zero address not allowed");
        require(_penLens != address(0), "Zero address not allowed");
        require(_swapper != address(0), "Zero address not allowed");

        gauge = IDystopiaLP(_gauge);
        dystPair = IDystopiaLP(_dystPair);
        _setDystopiaRouter(_dystRouter);
        oracleUsdc = IPriceFeed(_oracleUsdc);
        oracleTusd = IPriceFeed(_oracleTusd);
        userProxy = IUserProxy(_userProxy);
        penLens = IPenLens(_penLens);
        swapper = ISwapper(_swapper);
        stakeStep = _stakeStep;
        curveStablePool = _curveStablePool;
        curveMetaPool = _curveMetaPool;

    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {
        require(_asset == address(usdcToken), "Some token not compatible");

        (uint256 reserveUsdc, uint256 reserveTusd,) = dystPair.getReserves();
        require(reserveUsdc > 10 ** 3 && reserveTusd > 10 ** 15, 'Liquidity lpToken reserves too low');

        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 amountUsdcToSwap = _getAmountToken0(
            usdcBalance,
            reserveUsdc,
            reserveTusd,
            usdcTokenDenominator,
            tusdTokenDenominator,
            1,
            address(usdcToken),
            address(tusdToken)
        );

        // swap usdc to usdt
        ISwapper.SwapParams memory swapParams = ISwapper.SwapParams(
            address(usdcToken),
            address(tusdToken),
            amountUsdcToSwap,
            OvnMath.subBasisPoints(amountUsdcToSwap*(10**12), BASIS_POINTS_FOR_SLIPPAGE_EIGHT),
            1
        );
        IERC20(swapParams.tokenIn).approve(address(swapper), swapParams.amountIn);
        swapper.swap(swapParams);

        // add liquidity
        usdcBalance = usdcToken.balanceOf(address(this));
        uint256 tusdBalance = tusdToken.balanceOf(address(this));

        _addLiquidity(
            address(usdcToken),
            address(tusdToken),
            usdcBalance,
            tusdBalance,
            OvnMath.subBasisPoints(usdcBalance, BASIS_POINTS_FOR_SLIPPAGE),
            OvnMath.subBasisPoints(tusdBalance, BASIS_POINTS_FOR_SLIPPAGE),
            address(this)
        );

        uint256 lpTokenBalance = dystPair.balanceOf(address(this));
        dystPair.approve(address(userProxy), lpTokenBalance);
        userProxy.depositLpAndStake(address(dystPair), lpTokenBalance);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 currentUsdcBalance = usdcToken.balanceOf(address(this));
        if(currentUsdcBalance >= _amount)
            return _amount;


        (uint256 reserveUsdc, uint256 reserveTusd,) = dystPair.getReserves();
        require(reserveUsdc > 10 ** 3 && reserveTusd > 10 ** 15, 'Liquidity lpToken reserves too low');

        // Fetch amount of penPool LP currently staked
        address userProxyThis = penLens.userProxyByAccount(address(this));
        address stakingAddress = penLens.stakingRewardsByDystPool(address(dystPair));
        uint256 lpTokenBalance = IERC20(stakingAddress).balanceOf(userProxyThis);

        if (lpTokenBalance > 0) {
            // count amount to unstake
            uint256 totalLpBalance = dystPair.totalSupply();
            uint256 lpTokensToWithdraw = _getAmountLpTokens(
                OvnMath.addBasisPoints(_amount, BASIS_POINTS_FOR_SLIPPAGE) + 10,
                reserveUsdc,
                reserveTusd,
                totalLpBalance
            );

            if (lpTokensToWithdraw > lpTokenBalance) {
                lpTokensToWithdraw = lpTokenBalance;
            }

            userProxy.unstakeLpAndWithdraw(address(dystPair), lpTokensToWithdraw);

            uint256 unstakedLPTokenBalance = dystPair.balanceOf(address(this));

            // remove liquidity
            _removeLiquidity(
                address(usdcToken),
                address(tusdToken),
                address(dystPair),
                unstakedLPTokenBalance,
                0,
                0,
                address(this)
            );
        }

        // swap tusd to usdc
        uint256 tusdBalance = tusdToken.balanceOf(address(this));
        if (tusdBalance > 0) {

            tusdToken.approve(curveMetaPool, tusdBalance);
            CurveMetaLibrary.swapByIndex(
                curveIndexTusd,
                curveIndexUsdc,
                true,
                tusdBalance,
                0,
                curveMetaPool,
                curveStablePool
            );
        }

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        (uint256 reserveUsdc, uint256 reserveTusd,) = dystPair.getReserves();
        require(reserveUsdc > 10 ** 3 && reserveTusd > 10 ** 15, 'Liquidity lpToken reserves too low');

        // Fetch amount of penPool LP currently staked
        address userProxyThis = penLens.userProxyByAccount(address(this));
        address stakingAddress = penLens.stakingRewardsByDystPool(address(dystPair));
        uint256 lpTokenBalance = IERC20(stakingAddress).balanceOf(userProxyThis);
        if (lpTokenBalance == 0) {
            return usdcToken.balanceOf(address(this));
        }

        userProxy.unstakeLpAndWithdraw(address(dystPair), lpTokenBalance);

        uint256 unstakedLPTokenBalance = dystPair.balanceOf(address(this));
        if (unstakedLPTokenBalance > 0) {
            uint256 totalLpBalance = dystPair.totalSupply();

            // remove liquidity
            _removeLiquidity(
                address(usdcToken),
                address(tusdToken),
                address(dystPair),
                unstakedLPTokenBalance,
                0,
                0,
                address(this)
            );
        }

        // swap tusd to usdc
        uint256 tusdBalance = tusdToken.balanceOf(address(this));
        if (tusdBalance > 0) {

            tusdToken.approve(curveMetaPool, tusdBalance);

            CurveMetaLibrary.swapByIndex(
                curveIndexTusd,
                curveIndexUsdc,
                true,
                tusdBalance,
                0,
                curveMetaPool,
                curveStablePool
            );
        }

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue(true);
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue(false);
    }

    function _totalValue(bool nav) internal view returns (uint256) {
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 tusdBalance = tusdToken.balanceOf(address(this));

        // Fetch amount of penPool LP currently staked
        address userProxyThis = penLens.userProxyByAccount(address(this));
        address stakingAddress = penLens.stakingRewardsByDystPool(address(dystPair));
        uint256 lpTokenBalance = IERC20(stakingAddress).balanceOf(userProxyThis);
        if (lpTokenBalance > 0) {
            uint256 totalLpBalance = dystPair.totalSupply();
            (uint256 reserveUsdc, uint256 reserveTusd,) = dystPair.getReserves();
            usdcBalance += reserveUsdc * lpTokenBalance / totalLpBalance;
            tusdBalance += reserveTusd * lpTokenBalance / totalLpBalance;
        }

        uint256 usdcBalanceFromTusd;
        if (tusdBalance > 0) {
            if (nav) {
                usdcBalanceFromTusd = ChainlinkLibrary.convertTokenToToken(
                    tusdBalance,
                    tusdTokenDenominator,
                    usdcTokenDenominator,
                    oracleTusd,
                    oracleUsdc
                );
            } else {
                usdcBalanceFromTusd = _getAmountsOut(address(tusdToken), address(usdcToken), true, tusdBalance);
            }
        }

        return usdcBalance + usdcBalanceFromTusd;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards
        address userProxyThis = penLens.userProxyByAccount(address(this));
        address stakingAddress = penLens.stakingRewardsByDystPool(address(dystPair));
        uint256 lpTokenBalance = IERC20(stakingAddress).balanceOf(userProxyThis);
        if (lpTokenBalance > 0) {
            userProxy.claimStakingRewards();
        }

        // sell rewards
        uint256 totalUsdc;

        uint256 dystBalance = dystToken.balanceOf(address(this));
        if (dystBalance > 0) {
            uint256 dystUsdc = _swapExactTokensForTokens(
                address(dystToken),
                address(wmaticToken),
                address(usdcToken),
                false,
                false,
                dystBalance,
                address(this)
            );
            totalUsdc += dystUsdc;
        }

        uint256 penBalance = penToken.balanceOf(address(this));
        if (penBalance > 0) {
            uint256 penUsdc = _swapExactTokensForTokens(
                address(penToken),
                address(wmaticToken),
                address(usdcToken),
                false,
                false,
                penBalance,
                address(this)
            );
            totalUsdc += penUsdc;
        }

        usdcToken.transfer(_to, totalUsdc);

        return totalUsdc;
    }

    /**
     * Get amount of lp tokens where amount0Total is total getting amount nominated in token0
     *
     * precision: 0 - no correction, 1 - one correction (recommended value), 2 or more - several corrections
     */
    function _getAmountLpTokens(
        uint256 amount0Total,
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalLpBalance
    ) internal view returns (uint256) {
        uint256 lpBalance = (totalLpBalance * amount0Total * tusdTokenDenominator) / (reserve0 * tusdTokenDenominator + reserve1 * usdcTokenDenominator);

        uint256 amount1 = reserve1 * lpBalance / totalLpBalance;

        uint256 amount0 = _getAmountsOut(address(tusdToken), address(usdcToken), true, amount1);

        lpBalance = (totalLpBalance * amount0Total * amount1) / (reserve0 * amount1 + reserve1 * amount0);

        return lpBalance;
    }

    /**
    * Get amount of token1 nominated in token0 where amount0Total is total getting amount nominated in token0
    *
    * precision: 0 - no correction, 1 - one correction (recommended value), 2 or more - several corrections
    */
    function _getAmountToken0(
        uint256 amount0Total,
        uint256 reserve0,
        uint256 reserve1,
        uint256 denominator0,
        uint256 denominator1,
        uint256 precision,
        address token0,
        address token1
    ) internal view returns (uint256) {
        uint256 amount0 = (amount0Total * reserve1) / (reserve0 * denominator1 / denominator0 + reserve1);
        for (uint i = 0; i < precision; i++) {
            ISwapper.SwapParams memory swapParams = ISwapper.SwapParams(
                token0,
                token1,
                amount0,
                OvnMath.subBasisPoints(amount0*(10**12), BASIS_POINTS_FOR_SLIPPAGE_EIGHT),
                1
            );
            uint256 amount1 = swapper.getAmountOut(swapParams);
            amount0 = (amount0Total * reserve1) / (reserve0 * amount1 / amount0 + reserve1);
        }

        return amount0;
    }

}
