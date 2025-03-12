// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Beethovenx.sol";
import "@overnight-contracts/connectors/contracts/stuff/Arrakis.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";
import "@overnight-contracts/connectors/contracts/stuff/KyberSwap.sol";


contract StrategyArrakisDaiUsdc is Strategy {

    // --- params

    IERC20 public dai;
    IERC20 public usdc;
    IERC20 public op;
    IERC20 public weth;

    IArrakisV1RouterStaking public arrakisRouter;
    IArrakisRewards public arrakisRewards;
    IArrakisVault public arrakisVault;

    IVault public beethovenxVault;
    bytes32 public beethovenxPoolIdDai;
    bytes32 public beethovenxPoolIdDaiUsdtUsdc;
    bytes32 public beethovenxPoolIdUsdc;
    IERC20 public bbRfADai;
    IERC20 public bbRfAUsdc;

    ISwapRouter public uniswapV3Router;
    uint24 public poolWethOpFee;
    uint24 public poolWethDaiFee;

    IPriceFeed public oracleDai;
    IPriceFeed public oracleUsdc;

    uint256 public daiDm;
    uint256 public usdcDm;

    IRouter public kyberSwapRouter;
    uint24 public poolUsdcDaiFee;

    // --- structs

    struct StrategyParams {
        address dai;
        address usdc;
        address op;
        address weth;
        address arrakisRouter;
        address arrakisRewards;
        address arrakisVault;
        address beethovenxVault;
        bytes32 beethovenxPoolIdDai;
        bytes32 beethovenxPoolIdDaiUsdtUsdc;
        bytes32 beethovenxPoolIdUsdc;
        address bbRfADai;
        address bbRfAUsdc;
        address uniswapV3Router;
        uint24 poolWethOpFee;
        uint24 poolWethDaiFee;
        address oracleDai;
        address oracleUsdc;
        address kyberSwapRouter;
        uint24 poolUsdcDaiFee;
    }

    // --- events

    event StrategyUpdatedParams();

    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }

    // --- Setters

    function setParams(StrategyParams calldata params) external onlyAdmin {
        dai = IERC20(params.dai);
        usdc = IERC20(params.usdc);
        op = IERC20(params.op);
        weth = IERC20(params.weth);

        arrakisRouter = IArrakisV1RouterStaking(params.arrakisRouter);
        arrakisRewards = IArrakisRewards(params.arrakisRewards);
        arrakisVault = IArrakisVault(params.arrakisVault);

        beethovenxVault = IVault(params.beethovenxVault);
        beethovenxPoolIdDai = params.beethovenxPoolIdDai;
        beethovenxPoolIdDaiUsdtUsdc = params.beethovenxPoolIdDaiUsdtUsdc;
        beethovenxPoolIdUsdc = params.beethovenxPoolIdUsdc;
        bbRfADai = IERC20(params.bbRfADai);
        bbRfAUsdc = IERC20(params.bbRfAUsdc);

        uniswapV3Router = ISwapRouter(params.uniswapV3Router);
        poolWethOpFee = params.poolWethOpFee;
        poolWethDaiFee = params.poolWethDaiFee;

        oracleDai = IPriceFeed(params.oracleDai);
        oracleUsdc = IPriceFeed(params.oracleUsdc);

        daiDm = 10 ** IERC20Metadata(params.dai).decimals();
        usdcDm = 10 ** IERC20Metadata(params.usdc).decimals();

        kyberSwapRouter = IRouter(params.kyberSwapRouter);
        poolUsdcDaiFee = params.poolUsdcDaiFee;

        emit StrategyUpdatedParams();
    }

    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(dai), "Some token not compatible");

        // 1. Calculate needed DAI to swap to USDC
        (uint256 amountUsdcCurrent, uint256 amountDaiCurrent) = arrakisVault.getUnderlyingBalances();
        uint256 daiBalance = dai.balanceOf(address(this));
        BeethovenLibrary.SwapParams memory swapParams = BeethovenLibrary.SwapParams({
            beethovenxVault: beethovenxVault,
            kind: IVault.SwapKind.GIVEN_IN,
            token0: address(dai),
            token1: address(bbRfADai),
            token2: address(bbRfAUsdc),
            token3: address(usdc),
            poolId0: beethovenxPoolIdDai,
            poolId1: beethovenxPoolIdDaiUsdtUsdc,
            poolId2: beethovenxPoolIdUsdc,
            amount: 0,
            sender: address(this),
            recipient: address(this)
        });
        BeethovenLibrary.CalculateParams memory calculateParams = BeethovenLibrary.CalculateParams({
            amount0Total: daiBalance,
            totalLpBalance: 0,
            reserve0: amountDaiCurrent,
            reserve1: amountUsdcCurrent,
            denominator0: daiDm,
            denominator1: usdcDm,
            precision: 1
        });
        uint256 amountUsdcToSwap = BeethovenLibrary.getAmount1InToken0(swapParams, calculateParams);

        // 2. Swap DAI to needed USDC amount
        swapParams.amount = amountUsdcToSwap;
        BeethovenLibrary.batchSwap(swapParams);

        // 3. Stake DAI/USDC to Arrakis
        uint256 daiAmount = dai.balanceOf(address(this));
        uint256 usdcAmount = usdc.balanceOf(address(this));
        dai.approve(address(arrakisRouter), daiAmount);
        usdc.approve(address(arrakisRouter), usdcAmount);
        arrakisRouter.addLiquidityAndStake(
            address(arrakisRewards),
            usdcAmount,
            daiAmount,
            OvnMath.subBasisPoints(usdcAmount, 20),
            OvnMath.subBasisPoints(daiAmount, 20),
            address(this)
        );
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(dai), "Some token not compatible");

        // 1. Calculating need amount lp - depends on amount DAI/USDC
        (uint256 amountUsdcCurrent, uint256 amountDaiCurrent) = arrakisVault.getUnderlyingBalances();
        uint256 totalLpBalance = arrakisVault.totalSupply();
        BeethovenLibrary.SwapParams memory swapParams = BeethovenLibrary.SwapParams({
            beethovenxVault: beethovenxVault,
            kind: IVault.SwapKind.GIVEN_IN,
            token0: address(usdc),
            token1: address(bbRfAUsdc),
            token2: address(bbRfADai),
            token3: address(dai),
            poolId0: beethovenxPoolIdUsdc,
            poolId1: beethovenxPoolIdDaiUsdtUsdc,
            poolId2: beethovenxPoolIdDai,
            amount: 0,
            sender: address(this),
            recipient: address(this)
        });
        BeethovenLibrary.CalculateParams memory calculateParams = BeethovenLibrary.CalculateParams({
            // add 1 bp and 1e13 for unstake more than requested
            amount0Total: OvnMath.addBasisPoints(_amount + 1e13, 1),
            totalLpBalance: arrakisVault.totalSupply(),
            reserve0: amountDaiCurrent,
            reserve1: amountUsdcCurrent,
            denominator0: daiDm,
            denominator1: usdcDm,
            precision: 1
        });
        uint256 amountLp = BeethovenLibrary.getAmountLpTokens(swapParams, calculateParams);
        if (amountLp > totalLpBalance) {
            amountLp = totalLpBalance;
        }
        uint256 amountUsdc = amountUsdcCurrent * amountLp / totalLpBalance;
        uint256 amountDai = amountDaiCurrent * amountLp / totalLpBalance;

        // 2. Get DAI/USDC from Arrakis
        arrakisRewards.approve(address(arrakisRouter), amountLp);
        arrakisRouter.removeLiquidityAndUnstake(
            address(arrakisRewards),
            amountLp,
            OvnMath.subBasisPoints(amountUsdc, 20),
            OvnMath.subBasisPoints(amountDai, 20),
            address(this)
        );

        // 3. Swap USDC to DAI
        swapParams.amount = usdc.balanceOf(address(this));
        BeethovenLibrary.batchSwap(swapParams);

        return dai.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(dai), "Some token not compatible");

        // 1. Get balance LP
        uint256 amountLp = arrakisRewards.balanceOf(address(this));
        if (amountLp == 0) {
            return 0;
        }

        // 2. Calculating amount dai/usdc under lp
        (uint256 amountUsdcCurrent, uint256 amountDaiCurrent) = arrakisVault.getUnderlyingBalances();
        uint256 amountUsdc = amountUsdcCurrent * amountLp / arrakisVault.totalSupply();
        uint256 amountDai = amountDaiCurrent * amountLp / arrakisVault.totalSupply();

        // 3. Get dai/usdc from Arrakis
        arrakisRewards.approve(address(arrakisRouter), amountLp);
        arrakisRouter.removeLiquidityAndUnstake(
            address(arrakisRewards),
            amountLp,
            OvnMath.subBasisPoints(amountUsdc, 20),
            OvnMath.subBasisPoints(amountDai, 20),
            address(this)
        );

        // 4. Swap USDC to DAI
        BeethovenLibrary.SwapParams memory swapParams = BeethovenLibrary.SwapParams({
            beethovenxVault: beethovenxVault,
            kind: IVault.SwapKind.GIVEN_IN,
            token0: address(usdc),
            token1: address(bbRfAUsdc),
            token2: address(bbRfADai),
            token3: address(dai),
            poolId0: beethovenxPoolIdUsdc,
            poolId1: beethovenxPoolIdDaiUsdtUsdc,
            poolId2: beethovenxPoolIdDai,
            amount: usdc.balanceOf(address(this)),
            sender: address(this),
            recipient: address(this)
        });
        BeethovenLibrary.batchSwap(swapParams);

        return dai.balanceOf(address(this));
    }


    function netAssetValue() external override view returns (uint256) {
        return _totalValue(true);
    }

    function liquidationValue() external override view returns (uint256) {
        return _totalValue(false);
    }

    function _totalValue(bool nav) internal view returns (uint256){
        uint256 daiBalance = dai.balanceOf(address(this));
        uint256 usdcBalance = usdc.balanceOf(address(this));

        uint256 amountLp = arrakisRewards.balanceOf(address(this));
        if (amountLp > 0) {
            (uint256 amountUsdcCurrent, uint256 amountDaiCurrent) = arrakisVault.getUnderlyingBalances();
            usdcBalance += amountUsdcCurrent * amountLp / arrakisVault.totalSupply();
            daiBalance += amountDaiCurrent * amountLp / arrakisVault.totalSupply();
        }

        if (usdcBalance > 0) {
            uint256 daiBalanceInPool = _oracleUsdcToDai(usdcBalance);
            if (!nav) {
                daiBalanceInPool = OvnMath.subBasisPoints(daiBalanceInPool, 1);
            }
            daiBalance += daiBalanceInPool;
        }

        return daiBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards
        if (arrakisRewards.balanceOf(address(this)) > 0) {
            arrakisRewards.claim_rewards(address(this));
        }

        // sell rewards
        uint256 totalDai;

        uint256 opBalance = op.balanceOf(address(this));
        if (opBalance > 0) {
            uint256 opDai = UniswapV3Library.multiSwap(
                uniswapV3Router,
                address(op),
                address(weth),
                address(dai),
                poolWethOpFee,
                poolWethDaiFee,
                address(this),
                opBalance,
                0
            );

            totalDai += opDai;
        }

        if (totalDai > 0) {
            dai.transfer(_to, totalDai);
        }

        return totalDai;
    }

    function _oracleDaiToUsdc(uint256 daiAmount) internal view returns (uint256) {
        uint256 priceDai = uint256(oracleDai.latestAnswer());
        uint256 priceUsdc = uint256(oracleUsdc.latestAnswer());
        return ChainlinkLibrary.convertTokenToToken(daiAmount, daiDm, usdcDm, priceDai, priceUsdc);
    }

    function _oracleUsdcToDai(uint256 usdcAmount) internal view returns (uint256) {
        uint256 priceDai = uint256(oracleDai.latestAnswer());
        uint256 priceUsdc = uint256(oracleUsdc.latestAnswer());
        return ChainlinkLibrary.convertTokenToToken(usdcAmount, usdcDm, daiDm, priceUsdc, priceDai);
    }

}
