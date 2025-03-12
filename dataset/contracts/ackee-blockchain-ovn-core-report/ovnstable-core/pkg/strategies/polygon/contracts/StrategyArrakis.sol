// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Balancer.sol";
import "@overnight-contracts/connectors/contracts/stuff/Arrakis.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";


contract StrategyArrakis is Strategy, BalancerExchange {
    using OvnMath for uint256;

    uint256 constant BASIS_POINTS_FOR_SLIPPAGE = 4; // 0.04%

    IERC20 public usdcToken;
    IERC20 public usdtToken;
    IERC20 public wmaticToken;

    IArrakisV1RouterStaking arrakisRouter;
    IArrakisRewards arrakisRewards;
    IArrakisVault arrakisVault;

    IUniswapV3Pool uniswapV3Pool;
    INonfungiblePositionManager uniswapPositionManager;

    bytes32 public balancerPoolIdStable; // Stable Pool
    bytes32 public balancerPoolIdWmatic; // Wmatic/USDC Pool

    IPriceFeed public oracleUsdc;
    IPriceFeed public oracleUsdt;

    // --- events

    event StrategyUpdatedTokens(address usdcToken, address usdtToken, address wmaticToken);

    event StrategyUpdatedParams(address arrakisRouter, address arrakisRewards, address arrakisVault, address balancerVault, address uniswapPositionManager,
        bytes32 balancerPoolIdStable, bytes32 balancerPoolIdWmatic, address oracleUsdc, address oracleUsdt);


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _usdcToken,
        address _usdtToken,
        address _wmaticToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_usdtToken != address(0), "Zero address not allowed");
        require(_wmaticToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        usdtToken = IERC20(_usdtToken);
        wmaticToken = IERC20(_wmaticToken);

        emit StrategyUpdatedTokens(_usdcToken, _usdtToken, _wmaticToken);
    }

    function setParams(
        address _arrakisRouter,
        address _arrakisRewards,
        address _arrakisVault,
        address _balancerVault,
        bytes32 _balancerPoolIdStable,
        bytes32 _balancerPoolIdWmatic,
        address _uniswapPositionManager,
        address _oracleUsdc,
        address _oracleUsdt
    ) external onlyAdmin {

        require(_arrakisRouter != address(0), "Zero address not allowed");
        require(_arrakisRewards != address(0), "Zero address not allowed");
        require(_arrakisVault != address(0), "Zero address not allowed");
        require(_balancerVault != address(0), "Zero address not allowed");
        require(_uniswapPositionManager != address(0), "Zero address not allowed");
        require(_balancerPoolIdStable != "", "Empty pool id not allowed");
        require(_balancerPoolIdWmatic != "", "Empty pool id not allowed");
        require(_oracleUsdc != address(0), "Zero address not allowed");
        require(_oracleUsdt != address(0), "Zero address not allowed");

        arrakisRouter = IArrakisV1RouterStaking(_arrakisRouter);
        arrakisRewards = IArrakisRewards(_arrakisRewards);
        arrakisVault = IArrakisVault(_arrakisVault);

        balancerPoolIdStable = _balancerPoolIdStable;
        balancerPoolIdWmatic = _balancerPoolIdWmatic;
        setBalancerVault(_balancerVault);

        oracleUsdc = IPriceFeed(_oracleUsdc);
        oracleUsdt = IPriceFeed(_oracleUsdt);

        emit StrategyUpdatedParams(_arrakisRouter, _arrakisRewards, _arrakisVault, _balancerVault, _uniswapPositionManager,
            _balancerPoolIdStable, _balancerPoolIdWmatic, _oracleUsdc, _oracleUsdt);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {
        require(_asset == address(usdcToken), "Some token not compatible");

        // 1. Calculate needed USDC to swap to USDT
        (uint256 amountLiq0, uint256 amountLiq1) = arrakisVault.getUnderlyingBalances();
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 amountUsdcToSwap = _getAmountToSwap(
            usdcBalance,
            amountLiq0,
            amountLiq1,
            1,
            1,
            1,
            balancerPoolIdStable,
            usdcToken,
            usdtToken
        );


        // 2. Swap USDC to needed USDT amount
        swap(
            balancerPoolIdStable,
            IVault.SwapKind.GIVEN_IN,
            IAsset(address(usdcToken)),
            IAsset(address(usdtToken)),
            address(this),
            address(this),
            amountUsdcToSwap,
            0
        );


        // 3. Stake USDC/USDT to Arrakis
        uint256 usdcAmount = usdcToken.balanceOf(address(this));
        uint256 usdtAmount = usdtToken.balanceOf(address(this));
        usdcToken.approve(address(arrakisRouter), usdcAmount);
        usdtToken.approve(address(arrakisRouter), usdtAmount);

        arrakisRouter.addLiquidityAndStake(
            address(arrakisRewards),
            usdcAmount,
            usdtAmount,
            OvnMath.subBasisPoints(usdcAmount, BASIS_POINTS_FOR_SLIPPAGE),
            OvnMath.subBasisPoints(usdtAmount, BASIS_POINTS_FOR_SLIPPAGE),
            address(this)
        );
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {
        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 amount = OvnMath.addBasisPoints(_amount, BASIS_POINTS_FOR_SLIPPAGE);
        amount += 10;

        // 1. Calculating need amount lp tokens - depends on amount USDC/USDT
        (uint256 amount0Current, uint256 amount1Current) = arrakisVault.getUnderlyingBalances();
        uint256 totalLpBalance = arrakisVault.totalSupply();
        uint256 amountLp = _getAmountLpTokensToWithdraw(
                amount,
                amount0Current,
                amount1Current,
                arrakisVault.totalSupply(),
                1,
                1,
                balancerPoolIdStable,
                usdcToken,
                usdtToken
            );

        if (amountLp > totalLpBalance) {
            amountLp = totalLpBalance;
        }

        uint256 amountOut0Min = amount0Current * amountLp / totalLpBalance;
        uint256 amountOut1Min = amount1Current * amountLp / totalLpBalance;

        // 2. Get tokens USDC/USDT from Arrakis
        arrakisRewards.approve(address(arrakisRouter), amountLp);
        arrakisRouter.removeLiquidityAndUnstake(
            address(arrakisRewards),
            amountLp,
            OvnMath.subBasisPoints(amountOut0Min, BASIS_POINTS_FOR_SLIPPAGE),
            OvnMath.subBasisPoints(amountOut1Min, BASIS_POINTS_FOR_SLIPPAGE),
            address(this)
        );

        // 3. Swap USDT to USDC
        swap(balancerPoolIdStable, IVault.SwapKind.GIVEN_IN, IAsset(address(usdtToken)), IAsset(address(usdcToken)), address(this), address(this), usdtToken.balanceOf(address(this)), 0);

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {
        require(_asset == address(usdcToken), "Some token not compatible");


        // 1. Get balance LP tokens
        uint256 amountLp = arrakisRewards.balanceOf(address(this));

        if (amountLp == 0)
            return 0;


        // 2. Calculating amount usdc/usdt under lp tokens
        (uint256 amount0Current, uint256 amount1Current) = arrakisVault.getUnderlyingBalances();
        uint256 amountLiq0 = amount0Current * amountLp / arrakisVault.totalSupply();
        uint256 amountLiq1 = amount1Current * amountLp / arrakisVault.totalSupply();


        // 3. Get usdc/usdt tokens from Arrakis
        arrakisRewards.approve(address(arrakisRouter), amountLp);
        arrakisRouter.removeLiquidityAndUnstake(
            address(arrakisRewards),
            amountLp,
            OvnMath.subBasisPoints(amountLiq0, BASIS_POINTS_FOR_SLIPPAGE),
            OvnMath.subBasisPoints(amountLiq1, BASIS_POINTS_FOR_SLIPPAGE),
            address(this)
        );


        // 4. Swap USDT to USDC tokens on Balancer
        swap(balancerPoolIdStable, IVault.SwapKind.GIVEN_IN, IAsset(address(usdtToken)), IAsset(address(usdcToken)), address(this), address(this), usdtToken.balanceOf(address(this)), 0);

        return usdcToken.balanceOf(address(this));
    }


    function netAssetValue() external override view returns (uint256) {
        return _getTotal(true);
    }

    function liquidationValue() external override view returns (uint256) {
        return _getTotal(false);
    }

    function _getTotal(bool nav) internal view returns (uint256){

        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        uint256 balanceLp = arrakisRewards.balanceOf(address(this));

        if (balanceLp == 0)
            return 0;

        (uint256 amount0Current, uint256 amount1Current) = arrakisVault.getUnderlyingBalances();
        usdcBalance += amount0Current * balanceLp / arrakisVault.totalSupply();
        usdtBalance += amount1Current * balanceLp / arrakisVault.totalSupply();

        uint256 totalUsdtToUsdc;
        if(nav){
            uint256 priceUsdc = uint256(oracleUsdc.latestAnswer());
            uint256 priceUsdt = uint256(oracleUsdt.latestAnswer());
            totalUsdtToUsdc = ((usdtBalance * 1e6) * priceUsdt) / (1e6 * priceUsdc);
        }else {
            // check how many USDC tokens we will get if we sell USDT tokens now
            totalUsdtToUsdc = onSwap(balancerPoolIdStable, IVault.SwapKind.GIVEN_IN, usdtToken, usdcToken, usdtBalance);
        }
        return usdcBalance + totalUsdtToUsdc;

    }

    function _claimRewards(address _to) internal override returns (uint256) {

        if(arrakisRewards.balanceOf(address(this)) != 0){
            arrakisRewards.claim_rewards(address(this));
        }

        uint256 wmaticBalance = wmaticToken.balanceOf(address(this));

        if (wmaticBalance > 0) {

            uint256 usdcAmount = swap(balancerPoolIdWmatic, IVault.SwapKind.GIVEN_IN, IAsset(address(wmaticToken)),
                IAsset(address(usdcToken)), address(this), address(this), wmaticBalance, 0);

            usdcToken.transfer(_to, usdcAmount);
            return usdcAmount;
        } else {
            return 0;
        }
    }
}
