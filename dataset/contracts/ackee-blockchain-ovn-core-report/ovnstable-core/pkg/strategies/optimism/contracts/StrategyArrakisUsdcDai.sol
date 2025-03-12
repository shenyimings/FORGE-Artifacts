// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Beethovenx.sol";
import "@overnight-contracts/connectors/contracts/stuff/Arrakis.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";
import "@overnight-contracts/connectors/contracts/stuff/KyberSwap.sol";


contract StrategyArrakisUsdcDai is Strategy {

    // --- params

    IERC20 public usdc;
    IERC20 public dai;
    IERC20 public op;

    IArrakisV1RouterStaking public arrakisRouter;
    IArrakisRewards public arrakisRewards;
    IArrakisVault public arrakisVault;

    IVault public beethovenxVault;
    bytes32 public beethovenxPoolIdUsdc;
    bytes32 public beethovenxPoolIdDaiUsdtUsdc;
    bytes32 public beethovenxPoolIdDai;
    IERC20 public bbRfAUsdc;
    IERC20 public bbRfADai;

    ISwapRouter public uniswapV3Router;
    uint24 public poolUsdcOpFee;

    IPriceFeed public oracleUsdc;
    IPriceFeed public oracleDai;

    uint256 public usdcDm;
    uint256 public daiDm;

    IRouter public kyberSwapRouter;
    uint24 public poolUsdcDaiFee;

    // --- structs

    struct StrategyParams {
        address usdc;
        address dai;
        address op;
        address arrakisRouter;
        address arrakisRewards;
        address arrakisVault;
        address beethovenxVault;
        bytes32 beethovenxPoolIdUsdc;
        bytes32 beethovenxPoolIdDaiUsdtUsdc;
        bytes32 beethovenxPoolIdDai;
        address bbRfAUsdc;
        address bbRfADai;
        address uniswapV3Router;
        uint24 poolUsdcOpFee;
        address oracleUsdc;
        address oracleDai;
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
        usdc = IERC20(params.usdc);
        dai = IERC20(params.dai);
        op = IERC20(params.op);

        arrakisRouter = IArrakisV1RouterStaking(params.arrakisRouter);
        arrakisRewards = IArrakisRewards(params.arrakisRewards);
        arrakisVault = IArrakisVault(params.arrakisVault);

        beethovenxVault = IVault(params.beethovenxVault);
        beethovenxPoolIdUsdc = params.beethovenxPoolIdUsdc;
        beethovenxPoolIdDaiUsdtUsdc = params.beethovenxPoolIdDaiUsdtUsdc;
        beethovenxPoolIdDai = params.beethovenxPoolIdDai;
        bbRfAUsdc = IERC20(params.bbRfAUsdc);
        bbRfADai = IERC20(params.bbRfADai);

        uniswapV3Router = ISwapRouter(params.uniswapV3Router);
        poolUsdcOpFee = params.poolUsdcOpFee;

        oracleUsdc = IPriceFeed(params.oracleUsdc);
        oracleDai = IPriceFeed(params.oracleDai);

        usdcDm = 10 ** IERC20Metadata(params.usdc).decimals();
        daiDm = 10 ** IERC20Metadata(params.dai).decimals();

        kyberSwapRouter = IRouter(params.kyberSwapRouter);
        poolUsdcDaiFee = params.poolUsdcDaiFee;

        emit StrategyUpdatedParams();
    }

    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdc), "Some token not compatible");

        // 1. Calculate needed USDC to swap to DAI
        (uint256 amountUsdcCurrent, uint256 amountDaiCurrent) = arrakisVault.getUnderlyingBalances();
        uint256 usdcBalance = usdc.balanceOf(address(this));
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
            amount0Total: usdcBalance,
            totalLpBalance: 0,
            reserve0: amountUsdcCurrent,
            reserve1: amountDaiCurrent,
            denominator0: usdcDm,
            denominator1: daiDm,
            precision: 1
        });
        uint256 amountUsdcToSwap = BeethovenLibrary.getAmount1InToken0(swapParams, calculateParams);

        // 2. Swap USDC to needed DAI amount
        swapParams.amount = amountUsdcToSwap;
        BeethovenLibrary.batchSwap(swapParams);

        // 3. Stake USDC/DAI to Arrakis
        uint256 usdcAmount = usdc.balanceOf(address(this));
        uint256 daiAmount = dai.balanceOf(address(this));
        usdc.approve(address(arrakisRouter), usdcAmount);
        dai.approve(address(arrakisRouter), daiAmount);
        arrakisRouter.addLiquidityAndStake(
            address(arrakisRewards),
            usdcAmount,
            daiAmount,
            OvnMath.subBasisPoints(usdcAmount, 4),
            OvnMath.subBasisPoints(daiAmount, 4),
            address(this)
        );
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdc), "Some token not compatible");

        // 1. Calculating need amount lp - depends on amount USDC/DAI
        (uint256 amountUsdcCurrent, uint256 amountDaiCurrent) = arrakisVault.getUnderlyingBalances();
        uint256 totalLpBalance = arrakisVault.totalSupply();
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
            // add 1 bp and 10 for unstake more than requested
            amount0Total: OvnMath.addBasisPoints(_amount + 10, 1),
            totalLpBalance: arrakisVault.totalSupply(),
            reserve0: amountUsdcCurrent,
            reserve1: amountDaiCurrent,
            denominator0: usdcDm,
            denominator1: daiDm,
            precision: 1
        });
        uint256 amountLp = BeethovenLibrary.getAmountLpTokens(swapParams, calculateParams);
        if (amountLp > totalLpBalance) {
            amountLp = totalLpBalance;
        }
        uint256 amountUsdc = amountUsdcCurrent * amountLp / totalLpBalance;
        uint256 amountDai = amountDaiCurrent * amountLp / totalLpBalance;

        // 2. Get USDC/DAI from Arrakis
        arrakisRewards.approve(address(arrakisRouter), amountLp);
        arrakisRouter.removeLiquidityAndUnstake(
            address(arrakisRewards),
            amountLp,
            OvnMath.subBasisPoints(amountUsdc, 4),
            OvnMath.subBasisPoints(amountDai, 4),
            address(this)
        );

        // 3. Swap DAI to USDC
        swapParams.amount = dai.balanceOf(address(this));
        BeethovenLibrary.batchSwap(swapParams);

        return usdc.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdc), "Some token not compatible");

        // 1. Get balance LP
        uint256 amountLp = arrakisRewards.balanceOf(address(this));
        if (amountLp == 0) {
            return 0;
        }

        // 2. Calculating amount usdc/dai under lp
        (uint256 amountUsdcCurrent, uint256 amountDaiCurrent) = arrakisVault.getUnderlyingBalances();
        uint256 amountUsdc = amountUsdcCurrent * amountLp / arrakisVault.totalSupply();
        uint256 amountDai = amountDaiCurrent * amountLp / arrakisVault.totalSupply();

        // 3. Get usdc/dai from Arrakis
        arrakisRewards.approve(address(arrakisRouter), amountLp);
        arrakisRouter.removeLiquidityAndUnstake(
            address(arrakisRewards),
            amountLp,
            OvnMath.subBasisPoints(amountUsdc, 4),
            OvnMath.subBasisPoints(amountDai, 4),
            address(this)
        );

        // 4. Swap DAI to USDC
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
            amount: dai.balanceOf(address(this)),
            sender: address(this),
            recipient: address(this)
        });
        BeethovenLibrary.batchSwap(swapParams);

        return usdc.balanceOf(address(this));
    }


    function netAssetValue() external override view returns (uint256) {
        return _totalValue(true);
    }

    function liquidationValue() external override view returns (uint256) {
        return _totalValue(false);
    }

    function _totalValue(bool nav) internal view returns (uint256){
        uint256 usdcBalance = usdc.balanceOf(address(this));
        uint256 daiBalance = dai.balanceOf(address(this));

        uint256 amountLp = arrakisRewards.balanceOf(address(this));
        if (amountLp > 0) {
            (uint256 amountUsdcCurrent, uint256 amountDaiCurrent) = arrakisVault.getUnderlyingBalances();
            usdcBalance += amountUsdcCurrent * amountLp / arrakisVault.totalSupply();
            daiBalance += amountDaiCurrent * amountLp / arrakisVault.totalSupply();
        }

        if (daiBalance > 0) {
            uint256 usdcBalanceInPool = _oracleDaiToUsdc(daiBalance);
            if (!nav) {
                usdcBalanceInPool = OvnMath.subBasisPoints(usdcBalanceInPool, 1);
            }
            usdcBalance += usdcBalanceInPool;
        }

        return usdcBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards
        if (arrakisRewards.balanceOf(address(this)) > 0) {
            arrakisRewards.claim_rewards(address(this));
        }

        // sell rewards
        uint256 totalUsdc;

        uint256 opBalance = op.balanceOf(address(this));
        if (opBalance > 0) {
            uint256 opUsdc = UniswapV3Library.singleSwap(
                uniswapV3Router,
                address(op),
                address(usdc),
                poolUsdcOpFee,
                address(this),
                opBalance,
                0
            );

            totalUsdc += opUsdc;
        }

        if (totalUsdc > 0) {
            usdc.transfer(_to, totalUsdc);
        }

        return totalUsdc;
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
