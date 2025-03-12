// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/KyberSwap.sol";
import "@overnight-contracts/connectors/contracts/stuff/Synapse.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";

import "hardhat/console.sol";

contract StrategyKyberSwapUsdcDai is Strategy {

    IERC20 public usdcToken;
    IERC20 public daiToken;
    IERC20 public kncToken;

    IBasePositionManager public basePositionManager;
    IKyberSwapElasticLM public elasticLM;
    ReinvestmentToken public reinvestmentToken;
    uint256 public pid;

    IKyberPool public poolUsdcKnc;

    ISwap public synapseSwapRouter;
    uint24 public poolFeeUsdcDaiInUnits;

    IPriceFeed public oracleUsdc;
    IPriceFeed public oracleDai;

    uint256 public usdcTokenDenominator;
    uint256 public daiTokenDenominator;

    uint256 public tokenId;

    int24 public tickLower;
    int24 public tickUpper;


    // --- events

    event StrategyUpdatedParams();


    // --- structs

    struct StrategyParams {
        address usdcToken;
        address daiToken;
        address kncToken;
        address basePositionManager;
        address elasticLM;
        address reinvestmentToken;
        uint256 pid;
        address synapseSwapRouter;
        address poolUsdcKnc;
        uint24 poolFeeUsdcDaiInUnits;
        address oracleUsdc;
        address oracleDai;
        int24 tickLower;
        int24 tickUpper;
    }


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- setters

    function setParams(StrategyParams calldata params) external onlyAdmin {
        usdcToken = IERC20(params.usdcToken);
        daiToken = IERC20(params.daiToken);
        kncToken = IERC20(params.kncToken);

        basePositionManager = IBasePositionManager(params.basePositionManager);
        elasticLM = IKyberSwapElasticLM(params.elasticLM);
        reinvestmentToken = ReinvestmentToken(params.reinvestmentToken);
        pid = params.pid;

        synapseSwapRouter = ISwap(params.synapseSwapRouter);
        poolUsdcKnc = IKyberPool(params.poolUsdcKnc);

        poolFeeUsdcDaiInUnits = params.poolFeeUsdcDaiInUnits;

        oracleUsdc = IPriceFeed(params.oracleUsdc);
        oracleDai = IPriceFeed(params.oracleDai);

        tickLower = params.tickLower;
        tickUpper = params.tickUpper;

        usdcTokenDenominator = 10 ** IERC20Metadata(params.usdcToken).decimals();
        daiTokenDenominator = 10 ** IERC20Metadata(params.daiToken).decimals();

        emit StrategyUpdatedParams();
    }


    // --- logic

    function _swapUsdcToDai() internal {

        uint256 daiBalance = daiToken.balanceOf(address(this));
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        (uint160 sqrtP, , ,) = reinvestmentToken.getPoolState();
        uint256 price = getPoolPrice(tickLower, tickUpper, sqrtP);
        uint256 needDai = usdcBalance * price / (price + 10 ** 30);

        if(needDai > 0){
            SynapseLibrary.swap(
                synapseSwapRouter,
                address(usdcToken),
                address(daiToken),
                needDai
            );
        }

    }

    function getPriceBySqrtRatio(uint160 sqrtRatio) public returns (uint256) {
        uint256 price = FullMath.mulDiv(uint256(sqrtRatio) * 10**10, uint256(sqrtRatio) * 10**8, 2 ** (96+96));
        // console.log("getPriceBySqrtRatio", price);
        return price;
    }

    function getPriceByTick(int24 tick) public returns (uint256) {
        uint160 sqrtRatio = TickMath.getSqrtRatioAtTick(tick);
        uint256 price = FullMath.mulDiv(uint256(sqrtRatio) * 10**10, uint256(sqrtRatio) * 10**8, 2 ** (96+96));
        // console.log("getPriceByTick", price);
        return price;
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = x / 2 + 1;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function getPoolPrice(int24 lowerTick, int24 upperTick, uint160 sqrtRatio) public returns (uint256) {
        uint256 sa = sqrt(getPriceByTick(lowerTick));
        uint256 sb = sqrt(getPriceByTick(upperTick));
        uint256 sp = sqrt(getPriceBySqrtRatio(sqrtRatio));
        uint256 result = (sp * sb * (sp - sa)) / (sb - sp);
        return result;
    }

    function _addLiquidity() internal {

        // add liquidity
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 daiBalance = daiToken.balanceOf(address(this));
        usdcToken.approve(address(basePositionManager), usdcBalance);
        daiToken.approve(address(basePositionManager), daiBalance);

        console.log('1: USDC %s', usdcToken.balanceOf(address(this)) / 1e6);
        console.log('1: DAI  %s', daiToken.balanceOf(address(this)) / 1e18);
        if (tokenId == 0) {

            (int24 previousTickLower,) = reinvestmentToken.initializedTicks(tickLower);
            (int24 previousTickUpper,) = reinvestmentToken.initializedTicks(tickUpper);

            IBasePositionManager.MintParams memory params = IBasePositionManager.MintParams({
            token0 : address(usdcToken),
            token1 : address(daiToken),
            fee : poolFeeUsdcDaiInUnits,
            tickLower : tickLower,
            tickUpper : tickUpper,
            ticksPrevious : [previousTickLower, previousTickUpper],
            amount0Desired : usdcBalance,
            amount1Desired : daiBalance,
            amount0Min : 0,
            amount1Min : 0,
            recipient : address(this),
            deadline : block.timestamp
            });

            (uint256 tokenIdGen,,,) = basePositionManager.mint(params);
            tokenId = tokenIdGen;
        } else {

            IBasePositionManager.IncreaseLiquidityParams memory params = IBasePositionManager.IncreaseLiquidityParams({
            tokenId : tokenId,
            amount0Desired : usdcBalance,
            amount1Desired : daiBalance,
            amount0Min : 0,
            amount1Min : 0,
            deadline : block.timestamp
            });
            basePositionManager.addLiquidity(params);
        }

        console.log('2: USDC %s', usdcToken.balanceOf(address(this)) / 1e6);
        console.log('2: DAI  %s', daiToken.balanceOf(address(this)) / 1e18);
    }


    function _depositToGauge() internal {

        // 1. Deposit NFT to Farm Contract

        IERC721 nft = IERC721(address(basePositionManager));

        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = tokenId;

        uint256 liquidity;
        if(nft.ownerOf(tokenId) != address(elasticLM)){
            nft.approve(address(elasticLM), tokenId);
            elasticLM.deposit(nftIds);

        }else {
            (liquidity ,,) = elasticLM.getUserInfo(tokenId, pid);
        }

        // 2. Stake available liquidity to Farm Pool
        (IBasePositionManager.Position memory pos,) = basePositionManager.positions(tokenId);

        uint256[] memory liqs = new uint256[](1);
        liqs[0] = pos.liquidity - liquidity;

        elasticLM.join(pid, nftIds, liqs);
    }

    function _withdrawFromGauge() internal {

        (uint256 liquidity ,,) = elasticLM.getUserInfo(tokenId, pid);

        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = tokenId;
        uint256[] memory liqs = new uint256[](1);
        liqs[0] = liquidity;
        elasticLM.exit(pid, nftIds, liqs);
        elasticLM.withdraw(nftIds);
    }

    function _removeLiquidity(uint256 liquidity) internal {

        reinvestmentToken.approve(address(basePositionManager), liquidity);

        IBasePositionManager.RemoveLiquidityParams memory params = IBasePositionManager.RemoveLiquidityParams({
        tokenId : tokenId,
        liquidity : uint128(liquidity),
        amount0Min : 0,
        amount1Min : 0,
        deadline : block.timestamp
        });

        basePositionManager.removeLiquidity(params);
        basePositionManager.transferAllTokens(address(usdcToken), 0, address(this));
        basePositionManager.transferAllTokens(address(daiToken), 0, address(this));

    }

    function _swapAllDaiToUsdc() internal {

        uint256 daiBalance = daiToken.balanceOf(address(this));

        if (daiBalance > 0) {
            SynapseLibrary.swap(
                synapseSwapRouter,
                address(daiToken),
                address(usdcToken),
                daiBalance
            );
        }

    }

    function _getNeedToByDai(uint256 _amount) internal returns (uint256){

        (uint160 sqrtP, , ,) = reinvestmentToken.getPoolState();
        (uint128 baseL,,) = reinvestmentToken.getLiquidityState();

//        (uint256 amountLiq0, uint256 amountLiq1) = LiquidityAmounts.getAmountsForLiquidity(
//            sqrtP,
//            TickMath.getSqrtRatioAtTick(tickLower),
//            TickMath.getSqrtRatioAtTick(tickUpper),
//            baseL);
//
//        console.log('Amoun0 %s', amountLiq0);
//        console.log('Amoun1 %s', amountLiq1);
//
        uint256 needUsdtValue = 0;
        return needUsdtValue;
    }

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {
        require(_asset == address(usdcToken), "Some token not compatible");

        _swapUsdcToDai();

        _addLiquidity();

        _depositToGauge();

    }


    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {
        require(_asset == address(usdcToken), "Some token not compatible");

        _amount = OvnMath.addBasisPoints(_amount, 10); // add 0.1%

        uint256 amountDai = _getNeedToByDai(_amount);
        uint256 amountUsdc = _amount - amountDai;

        // 1. Withdraw liquidity and NFT from Gauge
        _withdrawFromGauge();

        uint128 liquidity = uint128(_amount * 2 * 10 ** 10);

        // 2. Unstake All liquidity from Pool
        _removeLiquidity(uint256(liquidity));

        // 3. Swap all USDT to USDC
        _swapAllDaiToUsdc();

        // 4. Deposit NFT and liquidity to Gauge
        _depositToGauge();

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        if(tokenId == 0){
            return usdcToken.balanceOf(address(this));
        }

        // 1. Withdraw Liquidity and NFT from Gauge
        _withdrawFromGauge();

        (IBasePositionManager.Position memory pos,) = basePositionManager.positions(tokenId);

        // 2. Unstake All liquidity from Pool
        _removeLiquidity(pos.liquidity);

        // 3. Swap all DAI to USDC
        _swapAllDaiToUsdc();

        tokenId = 0;

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue(true);
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue(false);
    }

    // function getAmount0Delta(
    //     uint160 sqrtRatioAX96,
    //     uint160 sqrtRatioBX96,
    //     uint128 liquidity
    // ) internal view returns (uint256 amount0) {
    //     console.log("sqrtRatioAX96", sqrtRatioAX96);
    //     console.log("sqrtRatioBX96", sqrtRatioBX96);
    //     console.log("liquidity", liquidity);
    //     if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

    //     uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;
    //     uint256 numerator2 = sqrtRatioBX96 - sqrtRatioAX96;

    //     console.log("numerator1", numerator1);
    //     console.log("numerator2", numerator2);

    //     require(sqrtRatioAX96 > 0);

    //     uint256 result = FullMath.mulDivRoundingUp(numerator1, numerator2, sqrtRatioBX96);
    //     console.log("result", result);

    //     return
    //         UnsafeMath.divRoundingUp(
    //                 FullMath.mulDivRoundingUp(numerator1, numerator2, sqrtRatioBX96),
    //                 sqrtRatioAX96
    //             );
    // }

    function _totalValue(bool nav) internal view returns (uint256) {
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 daiBalance = daiToken.balanceOf(address(this));

        if (tokenId > 0) {

            (IBasePositionManager.Position memory pos,) = basePositionManager.positions(tokenId);

            (uint160 sqrtP, , ,) = reinvestmentToken.getPoolState();

            uint160 sqrtUpper = TickMath.getSqrtRatioAtTick(pos.tickUpper);
            uint160 sqrtLower = TickMath.getSqrtRatioAtTick(pos.tickLower);
            usdcBalance += uint256(SqrtPriceMath.getAmount0Delta(sqrtP, sqrtUpper, int128(pos.liquidity)));
            daiBalance += uint256(SqrtPriceMath.getAmount1Delta(sqrtLower, sqrtP, int128(pos.liquidity)));

            if (nav) {
                usdcBalance += ChainlinkLibrary.convertTokenToToken(
                    daiBalance,
                    10 ** 18,
                    10 ** 6,
                    uint256(oracleDai.latestAnswer()),
                    uint256(oracleUsdc.latestAnswer())
                );
            } else {
                usdcBalance += SynapseLibrary.calculateSwap(
                    synapseSwapRouter,
                    address(daiToken),
                    address(usdcToken),
                    daiBalance
                );
            }

        }

        return usdcBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards
        if (tokenId > 0) {
            uint256[] memory nftIds = new uint256[](1);
            nftIds[0] = tokenId;

            uint256[] memory pIds = new uint256[](1);
            pIds[0] = pid;

            bytes[] memory datas = new bytes[](1);
            datas[0] = abi.encode(IKyberSwapElasticLM.HarvestData(pIds));
            elasticLM.harvestMultiplePools(nftIds, datas);
        }

        // sell rewards
        uint256 totalUsdc;

        uint256 kncBalance = kncToken.balanceOf(address(this));

        if (kncBalance > 0) {

            bool isFromToken0 = kncToken < usdcToken;

            IKyberPool.SwapCallbackData memory data = IKyberPool.SwapCallbackData({
                path: abi.encodePacked(address(kncToken), uint24(400), address(usdcToken)),
                source: address(this)
            });

            uint256 balanceUsdcBefore = usdcToken.balanceOf(address(this));

            poolUsdcKnc.swap(
                address(this),
                int256(kncBalance),
                isFromToken0,
                isFromToken0 ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
                new bytes(0)
            );

            uint256 balanceUsdcAfter = usdcToken.balanceOf(address(this));

            totalUsdc += balanceUsdcAfter - balanceUsdcBefore;

        }


        if (totalUsdc > 0) {
            usdcToken.transfer(_to, totalUsdc);
        }

        return totalUsdc;
    }

    function swapCallback(
        int256 deltaQty0,
        int256 deltaQty1,
        bytes calldata data
    ) external {
        kncToken.transfer(address(poolUsdcKnc), uint256(deltaQty0));
    }

}
