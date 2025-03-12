// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/swapper/contracts/ISwapper.sol";
import "@overnight-contracts/connectors/contracts/stuff/Dystopia.sol";
import "@overnight-contracts/connectors/contracts/stuff/Penrose.sol";
import "@overnight-contracts/connectors/contracts/stuff/Balancer.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";

contract StrategyDystopiaUsdcDai is Strategy, DystopiaExchange, BalancerExchange {

    IERC20 public usdcToken;
    IERC20 public daiToken;
    IERC20 public dystToken;
    IERC20 public wmaticToken;

    uint256 public usdcTokenDenominator;
    uint256 public daiTokenDenominator;

    IDystopiaLP public gauge;
    IDystopiaLP public dystPair;
    bytes32 public poolIdUsdcTusdDaiUsdt;

    IPriceFeed public oracleUsdc;
    IPriceFeed public oracleDai;

    IERC20 public penToken;
    IUserProxy public userProxy;
    IPenLens public penLens;

    ISwapper public swapper;


    // --- events

    event StrategyUpdatedTokens(address usdcToken, address usdtToken, address dystToken, address wmaticToken, address penToken,
        uint256 usdcTokenDenominator, uint256 daiTokenDenominator);

    event StrategyUpdatedParams(address gauge, address dystPair, address dystRouter, address balancerVault, bytes32 poolIdUsdcTusdDaiUsdt,
        address oracleUsdc, address oracleDai, address userProxy, address penLens, address swapper);


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _usdcToken,
        address _daiToken,
        address _dystToken,
        address _wmaticToken,
        address _penToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_daiToken != address(0), "Zero address not allowed");
        require(_dystToken != address(0), "Zero address not allowed");
        require(_wmaticToken != address(0), "Zero address not allowed");
        require(_penToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        daiToken = IERC20(_daiToken);
        dystToken = IERC20(_dystToken);
        wmaticToken = IERC20(_wmaticToken);
        penToken = IERC20(_penToken);
        usdcTokenDenominator = 10 ** IERC20Metadata(_usdcToken).decimals();
        daiTokenDenominator = 10 ** IERC20Metadata(_daiToken).decimals();

        emit StrategyUpdatedTokens(_usdcToken, _daiToken, _dystToken, _wmaticToken, _penToken, usdcTokenDenominator, daiTokenDenominator);
    }

    function setParams(
        address _gauge,
        address _dystPair,
        address _dystRouter,
        address _balancerVault,
        bytes32 _poolIdUsdcTusdDaiUsdt,
        address _oracleUsdc,
        address _oracleDai,
        address _userProxy,
        address _penLens,
        address _swapper
    ) external onlyAdmin {

        require(_gauge != address(0), "Zero address not allowed");
        require(_dystPair != address(0), "Zero address not allowed");
        require(_dystRouter != address(0), "Zero address not allowed");
        require(_balancerVault != address(0), "Zero address not allowed");
        require(_poolIdUsdcTusdDaiUsdt != "", "Empty pool id not allowed");
        require(_oracleUsdc != address(0), "Zero address not allowed");
        require(_oracleDai != address(0), "Zero address not allowed");
        require(_userProxy != address(0), "Zero address not allowed");
        require(_penLens != address(0), "Zero address not allowed");
        require(_swapper != address(0), "Zero address not allowed");

        gauge = IDystopiaLP(_gauge);
        dystPair = IDystopiaLP(_dystPair);
        _setDystopiaRouter(_dystRouter);
        setBalancerVault(_balancerVault);
        poolIdUsdcTusdDaiUsdt = _poolIdUsdcTusdDaiUsdt;
        oracleUsdc = IPriceFeed(_oracleUsdc);
        oracleDai = IPriceFeed(_oracleDai);
        userProxy = IUserProxy(_userProxy);
        penLens = IPenLens(_penLens);
        swapper = ISwapper(_swapper);

        emit StrategyUpdatedParams(_gauge, _dystPair, _dystRouter, _balancerVault, _poolIdUsdcTusdDaiUsdt, _oracleUsdc,
            _oracleDai, _userProxy, _penLens, _swapper);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        (uint256 reserveUsdc, uint256 reserveDai,) = dystPair.getReserves();
        require(reserveUsdc > 10 ** 3 && reserveDai > 10 ** 15, 'Liquidity lpToken reserves too low');

        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 amountUsdcToSwap = _getAmountToken0(
            usdcBalance,
            reserveUsdc,
            reserveDai,
            usdcTokenDenominator,
            daiTokenDenominator,
            1,
            address(usdcToken),
            address(daiToken)
        );

        // swap usdc to usdt
        ISwapper.SwapParams memory swapParams = ISwapper.SwapParams(
            address(usdcToken),
            address(daiToken),
            amountUsdcToSwap,
            0,
            5
        );
        IERC20(swapParams.tokenIn).approve(address(swapper), swapParams.amountIn);
        swapper.swap(swapParams);

        // add liquidity
        usdcBalance = usdcToken.balanceOf(address(this));
        uint256 daiBalance = daiToken.balanceOf(address(this));

        _addLiquidity(
            address(usdcToken),
            address(daiToken),
            usdcBalance,
            daiBalance,
            OvnMath.subBasisPoints(usdcBalance, BASIS_POINTS_FOR_SLIPPAGE),
            OvnMath.subBasisPoints(daiBalance, BASIS_POINTS_FOR_SLIPPAGE),
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

        (uint256 reserveUsdc, uint256 reserveDai,) = dystPair.getReserves();
        require(reserveUsdc > 10 ** 3 && reserveDai > 10 ** 15, 'Liquidity lpToken reserves too low');

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
                reserveDai,
                totalLpBalance
            );

            if (lpTokensToWithdraw > lpTokenBalance) {
                lpTokensToWithdraw = lpTokenBalance;
            }

            userProxy.unstakeLpAndWithdraw(address(dystPair), lpTokensToWithdraw);

            uint256 unstakedLPTokenBalance = dystPair.balanceOf(address(this));

            uint256 amountOutUsdcMin = reserveUsdc * unstakedLPTokenBalance / totalLpBalance;
            uint256 amountOutDaiMin = reserveDai * unstakedLPTokenBalance / totalLpBalance;

            // remove liquidity
            _removeLiquidity(
                address(usdcToken),
                address(daiToken),
                address(dystPair),
                unstakedLPTokenBalance,
                OvnMath.subBasisPoints(amountOutUsdcMin, BASIS_POINTS_FOR_SLIPPAGE),
                OvnMath.subBasisPoints(amountOutDaiMin, BASIS_POINTS_FOR_SLIPPAGE),
                address(this)
            );
        }

        // swap dai to usdc
        uint256 daiBalance = daiToken.balanceOf(address(this));
        ISwapper.SwapParams memory swapParams = ISwapper.SwapParams(
            address(daiToken),
            address(usdcToken),
            daiBalance,
            0,
            5
        );

        IERC20(swapParams.tokenIn).approve(address(swapper), swapParams.amountIn);
        swapper.swap(swapParams);

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        (uint256 reserveUsdc, uint256 reserveDai,) = dystPair.getReserves();
        require(reserveUsdc > 10 ** 3 && reserveDai > 10 ** 15, 'Liquidity lpToken reserves too low');

        // Fetch amount of penPool LP currently staked
        address userProxyThis = penLens.userProxyByAccount(address(this));
        address stakingAddress = penLens.stakingRewardsByDystPool(address(dystPair));
        uint256 lpTokenBalance = IERC20(stakingAddress).balanceOf(userProxyThis);
        if (lpTokenBalance == 0) {
            return 0;
        }

        userProxy.unstakeLpAndWithdraw(address(dystPair), lpTokenBalance);

        uint256 unstakedLPTokenBalance = dystPair.balanceOf(address(this));
        if (unstakedLPTokenBalance > 0) {
            uint256 totalLpBalance = dystPair.totalSupply();
            uint256 amountOutUsdcMin = reserveUsdc * unstakedLPTokenBalance / totalLpBalance;
            uint256 amountOutDaiMin = reserveDai * unstakedLPTokenBalance / totalLpBalance;

            // remove liquidity
            _removeLiquidity(
                address(usdcToken),
                address(daiToken),
                address(dystPair),
                unstakedLPTokenBalance,
                OvnMath.subBasisPoints(amountOutUsdcMin, BASIS_POINTS_FOR_SLIPPAGE),
                OvnMath.subBasisPoints(amountOutDaiMin, BASIS_POINTS_FOR_SLIPPAGE),
                address(this)
            );
        }

        // swap dai to usdc
        uint256 daiBalance = daiToken.balanceOf(address(this));
        ISwapper.SwapParams memory swapParams = ISwapper.SwapParams(
            address(daiToken),
            address(usdcToken),
            daiBalance,
            0,
            5
        );
        IERC20(swapParams.tokenIn).approve(address(swapper), swapParams.amountIn);
        swapper.swap(swapParams);

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
        uint256 daiBalance = daiToken.balanceOf(address(this));

        // Fetch amount of penPool LP currently staked
        address userProxyThis = penLens.userProxyByAccount(address(this));
        address stakingAddress = penLens.stakingRewardsByDystPool(address(dystPair));
        uint256 lpTokenBalance = IERC20(stakingAddress).balanceOf(userProxyThis);
        if (lpTokenBalance > 0) {
            uint256 totalLpBalance = dystPair.totalSupply();
            (uint256 reserveUsdc, uint256 reserveDai,) = dystPair.getReserves();
            usdcBalance += reserveUsdc * lpTokenBalance / totalLpBalance;
            daiBalance += reserveDai * lpTokenBalance / totalLpBalance;
        }

        uint256 usdcBalanceFromDai;
        if (daiBalance > 0) {
            if (nav) {
                usdcBalanceFromDai = ChainlinkLibrary.convertTokenToToken(daiBalance, daiTokenDenominator, usdcTokenDenominator, oracleDai, oracleUsdc);
            } else {
                ISwapper.SwapParams memory swapParams = ISwapper.SwapParams(
                    address(daiToken),
                    address(usdcToken),
                    daiBalance,
                    0,
                    5
                );
                usdcBalanceFromDai = swapper.getAmountOut(swapParams);
            }
        }

        return usdcBalance + usdcBalanceFromDai;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards
        userProxy.claimStakingRewards();

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

        usdcToken.transfer(_to, usdcToken.balanceOf(address(this)));

        return totalUsdc;
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
                0,
                5
            );
            uint256 amount1 = swapper.getAmountOut(swapParams);
            amount0 = (amount0Total * reserve1) / (reserve0 * amount1 / amount0 + reserve1);
        }

        return amount0;
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
        uint256 lpBalance = (totalLpBalance * amount0Total * daiTokenDenominator) / (reserve0 * daiTokenDenominator + reserve1 * usdcTokenDenominator);

        uint256 amount1 = reserve1 * lpBalance / totalLpBalance;
        ISwapper.SwapParams memory swapParams = ISwapper.SwapParams(
            address(daiToken),
            address(usdcToken),
            amount1,
            0,
            5
        );
        uint256 amount0 = swapper.getAmountOut(swapParams);
        lpBalance = (totalLpBalance * amount0Total * amount1) / (reserve0 * amount1 + reserve1 * amount0);

        return lpBalance;
    }

}
