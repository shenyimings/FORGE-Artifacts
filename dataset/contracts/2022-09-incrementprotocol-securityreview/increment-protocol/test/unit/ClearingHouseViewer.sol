// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

// contracts
import {Deployment} from "../helpers/Deployment.MainnetFork.sol";

// interfaces
import {IClearingHouseViewer} from "../../contracts/interfaces/IClearingHouseViewer.sol";

// libraries
import {LibPerpetual} from "../../contracts/lib/LibPerpetual.sol";
import "../../contracts/lib/LibMath.sol";

contract ClearingHouseViewer is Deployment {
    // events
    event FundingPaid(
        address indexed account,
        int256 amount,
        int256 globalCumulativeFundingRate,
        int256 userCumulativeFundingRate,
        bool isTrader
    );

    // libraries
    using LibMath for uint256;
    using LibMath for int256;

    // constants
    uint256 constant VQUOTE_INDEX = 0;
    uint256 constant VBASE_INDEX = 1;

    // addresses
    address lp = address(123);
    address lpTwo = address(456);
    address trader = address(789);

    // config values
    uint256 maxTradeAmount;
    uint256 minTradeAmount;
    uint256 vBaseLastUpdate;

    function _dealAndDeposit(address addr, uint256 amount) internal {
        deal(address(ua), addr, amount);
        vm.startPrank(addr);
        ua.approve(address(vault), amount);
        clearingHouse.deposit(amount, ua);
        vm.stopPrank();
    }

    function _dealAndProvideLiquidity(address addr, uint256 amount) internal {
        _dealAndDeposit(addr, amount);
        uint256 quoteAmount = amount / 2;
        uint256 baseAmount = quoteAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.startPrank(addr);
        clearingHouse.provideLiquidity(0, [quoteAmount, baseAmount], 0);
        vm.stopPrank();
    }

    function setUp() public override {
        super.setUp();
        maxTradeAmount = perpetual.maxPosition();
        minTradeAmount = clearingHouse.minPositiveOpenNotional();
        (,,, vBaseLastUpdate,) = baseOracle.latestRoundData();
    }

    function testFuzz_ReturnsCorrectDy(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        _dealAndProvideLiquidity(lp, tradeAmount);
        assertEq(
            viewer.getExpectedVBaseAmount(0, tradeAmount), cryptoSwap.get_dy(VQUOTE_INDEX, VBASE_INDEX, tradeAmount)
        );
        assertEq(
            viewer.getExpectedVQuoteAmount(0, tradeAmount), cryptoSwap.get_dy(VBASE_INDEX, VQUOTE_INDEX, tradeAmount)
        );
    }

    function testFuzz_ReturnsCorrectDyNoFeeDeduct(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        _dealAndProvideLiquidity(lp, tradeAmount);
        assertEq(
            viewer.getExpectedVBaseAmountExFees(0, tradeAmount),
            curveCryptoViews.get_dy_no_fee_deduct(cryptoSwap, VQUOTE_INDEX, VBASE_INDEX, tradeAmount)
        );
        assertEq(
            viewer.getExpectedVQuoteAmountExFees(0, tradeAmount),
            curveCryptoViews.get_dy_no_fee_deduct(cryptoSwap, VBASE_INDEX, VQUOTE_INDEX, tradeAmount)
        );
    }

    function testFuzz_ReturnsCorrectDxExFees(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        _dealAndProvideLiquidity(lp, tradeAmount * 10);
        assertEq(
            viewer.getExpectedVBaseToReceiveAmountExFees(0, tradeAmount),
            curveCryptoViews.get_dx_ex_fees(cryptoSwap, VQUOTE_INDEX, VBASE_INDEX, tradeAmount)
        );
        assertEq(
            viewer.getExpectedVQuoteAmountToReceiveExFees(0, tradeAmount),
            curveCryptoViews.get_dx_ex_fees(cryptoSwap, VQUOTE_INDEX, VBASE_INDEX, tradeAmount)
        );
    }

    function testFuzz_ReturnsCorrectCalcTokenAmount(uint256 tradeAmount, uint256 quoteAmount, uint256 baseAmount)
        public
    {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        quoteAmount = bound(quoteAmount, minTradeAmount, tradeAmount * 10);
        baseAmount = bound(baseAmount, minTradeAmount.wadDiv(perpetual.indexPrice().toUint256()), tradeAmount * 10);

        _dealAndProvideLiquidity(lp, tradeAmount);

        assertEq(
            viewer.getExpectedLpTokenAmount(0, [quoteAmount, baseAmount]),
            cryptoSwap.calc_token_amount([quoteAmount, baseAmount])
        );
    }

    function testFuzz_FailsExpectedVirtualTokenAmountsFromLpTokenAmountWhenLargerThanBalance(uint256 tradeAmount)
        public
    {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        _dealAndProvideLiquidity(lp, tradeAmount);

        uint256 lpBalance = viewer.getLpPosition(0, lp).liquidityBalance;

        vm.expectRevert(IClearingHouseViewer.ClearingHouseViewer_LpTokenAmountPassedLargerThanBalance.selector);
        viewer.getExpectedVirtualTokenAmountsFromLpTokenAmount(0, lp, lpBalance + 1);
    }

    function testFuzz_ReturnsExpectedVTokenAmountsFromLpTokenAmount(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        _dealAndProvideLiquidity(lp, tradeAmount);

        uint256 lpTokenBalance = viewer.getLpPosition(0, lp).liquidityBalance;
        uint256 lpTotalSupply = viewer.totalLpTokenSupply(0);

        uint256 expectedQuoteTokenWithdrawn = ((lpTokenBalance - 1) * cryptoSwap.balances(VQUOTE_INDEX)) / lpTotalSupply;
        uint256 expectedBaseTokenWithdrawn = ((lpTokenBalance - 1) * cryptoSwap.balances(VBASE_INDEX)) / lpTotalSupply;

        uint256[2] memory vTokenAmounts = viewer.getExpectedVirtualTokenAmountsFromLpTokenAmount(0, lp, lpTokenBalance);

        assertEq(vTokenAmounts[VQUOTE_INDEX], expectedQuoteTokenWithdrawn);
        assertEq(vTokenAmounts[VBASE_INDEX], expectedBaseTokenWithdrawn);

        (uint256 perpQuoteTokenAmount, uint256 perpBaseTokenAmount) =
            perpetual.__TestPerpetual__getWithdrawableTokens(lp, lpTokenBalance);

        assertEq(vTokenAmounts[VQUOTE_INDEX], perpQuoteTokenAmount);
        assertEq(vTokenAmounts[VBASE_INDEX], perpBaseTokenAmount);
    }

    function test_ReturnsCorrectMarketPrice() public {
        assertEq(viewer.marketPrice(0), perpetual.marketPrice());
    }

    function test_ReturnsCorrectIndexPrice() public {
        assertEq(viewer.indexPrice(0), perpetual.indexPrice());
    }

    function test_ReturnsCorrectGlobalPosition() public {
        LibPerpetual.GlobalPosition memory viewerGlobalPosition = viewer.getGlobalPosition(0);
        LibPerpetual.GlobalPosition memory perpGlobalPosition = perpetual.getGlobalPosition();

        assertEq(viewerGlobalPosition.timeOfLastTrade, perpGlobalPosition.timeOfLastTrade);
        assertEq(viewerGlobalPosition.timeOfLastTwapUpdate, perpGlobalPosition.timeOfLastTwapUpdate);
        assertEq(viewerGlobalPosition.cumFundingRate, perpGlobalPosition.cumFundingRate);
        assertEq(viewerGlobalPosition.totalQuoteProvided, perpGlobalPosition.totalQuoteProvided);
        assertEq(viewerGlobalPosition.totalBaseProvided, perpGlobalPosition.totalBaseProvided);
        assertEq(viewerGlobalPosition.cumFundingPerLpToken, perpGlobalPosition.cumFundingPerLpToken);
        assertEq(viewerGlobalPosition.currentBlockTradeAmount, perpGlobalPosition.currentBlockTradeAmount);
        assertEq(viewerGlobalPosition.totalTradingFeesGrowth, perpGlobalPosition.totalTradingFeesGrowth);
        assertEq(viewerGlobalPosition.totalBaseFeesGrowth, perpGlobalPosition.totalBaseFeesGrowth);
        assertEq(viewerGlobalPosition.totalQuoteFeesGrowth, perpGlobalPosition.totalQuoteFeesGrowth);
        assertEq(viewerGlobalPosition.traderLongs, perpGlobalPosition.traderLongs);
        assertEq(viewerGlobalPosition.traderShorts, perpGlobalPosition.traderShorts);
    }

    function test_ReturnsCorrectAddressOfMarket() public {
        assertEq(address(viewer.getMarket(0)), address(cryptoSwap));
    }

    function test_ReturnsCorrectAddressOfPerpetual() public {
        assertEq(address(viewer.perpetual(0)), address(perpetual));
    }

    function test_ReturnsCorrectInsuranceFee() public {
        assertEq(viewer.insuranceFee(0), perpetual.insuranceFee());
    }

    function test_ReturnsCorrectBaseBalance() public {
        assertEq(viewer.getBaseBalance(0), cryptoSwap.balances(VBASE_INDEX));
    }

    function test_ReturnsCorrectQuoteBalance() public {
        assertEq(viewer.getQuoteBalance(0), cryptoSwap.balances(VQUOTE_INDEX));
    }

    function test_ReturnsCorrectTotalLiquidityProvided() public {
        assertEq(viewer.getTotalLiquidityProvided(0), lpToken.totalSupply());
    }

    function testFuzz_ReturnsCorrectFreeCollateralByRatioAcrossAllMarkets(uint256 tradeAmount, bool shouldTrade)
        public
    {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        int256 minMarginAtCreation = clearingHouse.minMarginAtCreation();

        assertEq(viewer.getReserveValue(trader, false), tradeAmount.toInt256());

        if (shouldTrade) {
            // create user position
            vm.startPrank(trader);
            clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
            vm.stopPrank();
        }

        int256 pnl = clearingHouse.getPnLAcrossMarkets(trader);
        int256 fundingPayments = viewer.getFundingPaymentsAcrossMarkets(trader);
        int256 userDebt = clearingHouse.getDebtAcrossMarkets(trader);
        int256 reserveValue = viewer.getReserveValue(trader, false);

        int256 marginRequired = minMarginAtCreation.wadMul(userDebt);

        int256 expectedFreeCollateral = pnl > 0
            ? reserveValue + fundingPayments - marginRequired
            : reserveValue + pnl + fundingPayments - marginRequired;

        assertEq(viewer.getFreeCollateralByRatio(trader, minMarginAtCreation), expectedFreeCollateral);
    }

    function testFuzz_ReturnsTrueIfMarginIsValid(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        int256 minMarginAtCreation = clearingHouse.minMarginAtCreation();
        assertTrue(viewer.isMarginValid(trader, minMarginAtCreation));
        assertTrue(viewer.isMarginValid(trader, 0));

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        // create user position
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        int256 marginRatio = viewer.marginRatio(trader);

        assertTrue(viewer.isMarginValid(trader, marginRatio));

        assertTrue(!viewer.isMarginValid(trader, marginRatio + 1));
    }

    function testFuzz_ReturnsCorrectLeverageAcrossMarkets(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        assertEq(viewer.accountLeverage(trader), 0);

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        // create user position
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        int256 pnl = clearingHouse.getPnLAcrossMarkets(trader);
        int256 fundingPayments = viewer.getFundingPaymentsAcrossMarkets(trader);
        int256 userDebt = clearingHouse.getDebtAcrossMarkets(trader);
        int256 reserveValue = viewer.getReserveValue(trader, false);

        int256 expectedAccountLeverage =
            userDebt.abs().wadDiv(reserveValue + (pnl > 0 ? int256(0) : pnl) + fundingPayments);

        assertEq(viewer.accountLeverage(trader), expectedAccountLeverage);
    }

    function testFuzz_ReturnsCorrectLeverageForSpecificMarket(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        assertEq(viewer.marketLeverage(0, trader), 0);

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        // create user position
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        int256 riskWeight = perpetual.riskWeight().toInt256();
        int256 pnl = clearingHouse.getPnLAcrossMarkets(trader);
        int256 fundingPayments = viewer.getFundingPaymentsAcrossMarkets(trader);
        int256 userDebt = clearingHouse.getDebtAcrossMarkets(trader).wadMul(riskWeight);
        int256 reserveValue = viewer.getReserveValue(trader, false);

        int256 expectedAccountLeverage =
            userDebt.abs().wadDiv(reserveValue + (pnl > 0 ? int256(0) : pnl) + fundingPayments);

        assertEq(viewer.marketLeverage(0, trader), expectedAccountLeverage);
    }

    function testFuzz_ReturnsCorrectFundingPaymetsAcrossMarkets(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        // create user position
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        int256 expectedFundingPayments = viewer.getFundingPayments(0, trader);

        assertEq(viewer.getFundingPaymentsAcrossMarkets(trader), expectedFundingPayments);
    }

    function testFuzz_ReturnsCorrectLpFundingPaymentsAcrossMarkets(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        int256 expectedLpFundingPayments = viewer.getLpFundingPayments(0, lp);

        assertEq(viewer.getFundingPaymentsAcrossMarkets(lp), expectedLpFundingPayments);
    }

    function testFuzz_ReturnsCorrectFundingPaymentsForSpecificMarket(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        // create user position
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        int256 expectedFundingPayments = viewer.getTraderFundingPayments(0, trader);
        int256 expectedLpFundingPayments = viewer.getLpFundingPayments(0, trader);

        assertEq(viewer.getFundingPayments(0, trader), expectedFundingPayments + expectedLpFundingPayments);
    }

    function testFuzz_ReturnsCorrectTraderFundingPaymentsForSpecificMarket(uint256 tradeAmount, uint256 durationPassed)
        public
    {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        durationPassed = bound(durationPassed, 0, vBase.heartBeat() - (block.timestamp - vBaseLastUpdate));

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        // create user position
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        // skip some time
        vm.warp(block.timestamp + durationPassed);

        LibPerpetual.TraderPosition memory traderPosition = viewer.getTraderPosition(0, trader);
        (int256 cumFundingRate,) = viewer.getUpdatedFundingRate(0);
        int256 expectedTraderFundingPayments = 0;
        if (traderPosition.cumFundingRate != cumFundingRate) {
            int256 upcomingFundingRate = traderPosition.positionSize >= 0
                ? traderPosition.cumFundingRate - cumFundingRate
                : cumFundingRate - traderPosition.cumFundingRate;
            expectedTraderFundingPayments = upcomingFundingRate.wadMul(int256(traderPosition.positionSize).abs());
        }

        assertEq(viewer.getTraderFundingPayments(0, trader), expectedTraderFundingPayments);
    }

    function testFuzz_ReturnsCorrectLpFundingPaymentsForSpecificMarket(uint256 tradeAmount, uint256 durationPassed)
        public
    {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        durationPassed = bound(durationPassed, 0, vBase.heartBeat() - (block.timestamp - vBaseLastUpdate));

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        // create user position
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        // skip some time
        vm.warp(block.timestamp + durationPassed);

        LibPerpetual.LiquidityProviderPosition memory lpPosition = viewer.getLpPosition(0, lp);
        (, int256 cumFundingPerLpToken) = viewer.getUpdatedFundingRate(0);
        int256 expectedLpFundingPayments = (cumFundingPerLpToken - lpPosition.cumFundingPerLpToken).wadMul(
            uint256(lpPosition.liquidityBalance).toInt256()
        );

        assertEq(viewer.getLpFundingPayments(0, lp), expectedLpFundingPayments);
    }

    function testFuzz_ReturnsCorrectLpTradingFeeForSpecificMarket(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        assertEq(viewer.getLpTradingFees(0, lp), 0);

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        uint256 expectedLpTradingFees = perpetual.getLpTradingFees(lp);

        assertEq(viewer.getLpTradingFees(0, lp), expectedLpTradingFees);
    }

    function testFuzz_ReturnsCorrectUnrealizedPnLForSpecificMarket(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        int256 expectedUnrealizedPnL = perpetual.getTraderUnrealizedPnL(trader);

        assertEq(viewer.getTraderUnrealizedPnL(0, trader), expectedUnrealizedPnL);
    }

    function testFuzz_ReturnsCorrectLpUnrealizedPnLForSpecificMarket(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        assertEq(viewer.getLpUnrealizedPnL(0, lp), 0);

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        int256 expectedLpUnrealizedPnL = perpetual.getLpUnrealizedPnL(lp);

        assertEq(viewer.getLpUnrealizedPnL(0, lp), expectedLpUnrealizedPnL);
    }

    function testFuzz_ReturnsCorrectLpEstimatedPnlForSpecificMarket(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        assertEq(viewer.getLpEstimatedPnl(0, lp), 0);

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        int256 lpUnrealizedPnl = perpetual.getLpUnrealizedPnL(lp);
        int256 lpTradingFees = perpetual.getLpTradingFees(lp).toInt256();

        assertEq(viewer.getLpEstimatedPnl(0, lp), lpUnrealizedPnl + lpTradingFees);
    }

    function testFuzz_ReturnsLpPositionAfterWithdrawalForSpecificMarket(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        _dealAndProvideLiquidity(lp, tradeAmount);

        LibPerpetual.TraderPosition memory viewerLpPosition = viewer.getLpPositionAfterWithdrawal(0, lp);
        LibPerpetual.TraderPosition memory perpLpPosition = perpetual.getLpPositionAfterWithdrawal(lp);

        assertEq(viewerLpPosition.openNotional, perpLpPosition.openNotional);
        assertEq(viewerLpPosition.positionSize, perpLpPosition.positionSize);
        assertEq(viewerLpPosition.cumFundingRate, perpLpPosition.cumFundingRate);
    }

    function testFuzz_ReturnsCorrectReserveValueFromVault(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        _dealAndDeposit(trader, tradeAmount);

        assertEq(viewer.getReserveValue(trader, false), vault.getReserveValue(trader, false));
        assertEq(viewer.getReserveValue(trader, true), vault.getReserveValue(trader, true));
    }

    function testFuzz_ReturnsCorrectCollateralBalanceFromVault(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        _dealAndDeposit(trader, tradeAmount);

        assertEq(viewer.getBalance(trader, 0), vault.getBalance(trader, 0));
    }

    function testFuzz_ReturnsIsTraderPositionOpen(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        assertEq(viewer.isTraderPositionOpen(0, trader), false);

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        assertEq(viewer.isTraderPositionOpen(0, trader), false);

        // create user position
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        assertEq(viewer.isTraderPositionOpen(0, trader), true);
    }

    function testFuzz_ReturnsIsLpPositionOpen(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        assertEq(viewer.isLpPositionOpen(0, lp), false);
        assertEq(viewer.isLpPositionOpen(0, trader), false);

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        assertEq(viewer.isLpPositionOpen(0, lp), true);

        // create user position
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        assertEq(viewer.isLpPositionOpen(0, trader), false);
    }

    function testFuzz_ReturnsPositionOpenInAnyMarket(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        assertEq(viewer.isPositionOpen(trader), false);

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        assertEq(viewer.isPositionOpen(trader), false);

        // create user position
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        assertEq(viewer.isPositionOpen(trader), true);
    }

    function testFuzz_ReturnsCurrectLpPositionForSpecificMarket(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        LibPerpetual.LiquidityProviderPosition memory viewerLpPosition = viewer.getLpPosition(0, lp);
        LibPerpetual.LiquidityProviderPosition memory perpLpPosition = perpetual.getLpPosition(lp);

        assertEq(viewerLpPosition.openNotional, perpLpPosition.openNotional);
        assertEq(viewerLpPosition.positionSize, perpLpPosition.positionSize);
        assertEq(viewerLpPosition.liquidityBalance, perpLpPosition.liquidityBalance);
        assertEq(viewerLpPosition.depositTime, perpLpPosition.depositTime);
        assertEq(viewerLpPosition.totalTradingFeesGrowth, perpLpPosition.totalTradingFeesGrowth);
        assertEq(viewerLpPosition.totalBaseFeesGrowth, perpLpPosition.totalBaseFeesGrowth);
        assertEq(viewerLpPosition.totalQuoteFeesGrowth, perpLpPosition.totalQuoteFeesGrowth);
        assertEq(viewerLpPosition.cumFundingPerLpToken, perpLpPosition.cumFundingPerLpToken);
    }

    function testFuzz_ReturnsCorrectDustBalanceForSpecificMarket(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);
        assertEq(viewer.getBaseDust(0), 0);

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        // create user position
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        // close position
        uint256 proposedAmount = viewer.getTraderProposedAmount(0, trader, 1 ether, 100, 0);
        vm.startPrank(trader);
        clearingHouse.changePosition(0, proposedAmount, 0, LibPerpetual.Side.Short);
        vm.stopPrank();

        assertEq(viewer.getBaseDust(0), perpetual.getTraderPosition(address(clearingHouse)).positionSize);
    }

    function testFuzz_ReturnsAcceptableValueForTraderProposedAmountLong(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        // create user position
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        // close position
        uint256 proposedAmount = viewer.getTraderProposedAmount(0, trader, 1 ether, 100, 0);
        vm.startPrank(trader);
        clearingHouse.changePosition(0, proposedAmount, 0, LibPerpetual.Side.Short);
        vm.stopPrank();

        // ensure user position is closed
        assertEq(viewer.isTraderPositionOpen(0, trader), false);
    }

    function testFuzz_ReturnsAcceptableValueForTraderProposedAmountShort(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 4);

        _dealAndProvideLiquidity(lp, tradeAmount * 2);
        _dealAndDeposit(trader, tradeAmount);

        // create user position
        tradeAmount = tradeAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Short);
        vm.stopPrank();

        // close position
        uint256 proposedAmount = viewer.getTraderProposedAmount(0, trader, 1 ether, 100, 0);
        vm.startPrank(trader);
        clearingHouse.changePosition(0, proposedAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        // ensure user position is closed
        assertEq(viewer.isTraderPositionOpen(0, trader), false);
    }

    function test_FailsToProvideProposedAmountWithReductionAboveOneEther() public {
        vm.expectRevert(IClearingHouseViewer.ClearingHouseViewer_ReductionRatioTooLarge.selector);
        viewer.getTraderProposedAmount(0, trader, 1 ether + 1, 1, 0);
    }

    function testFuzz_FailsWhenLpMinAmountIsNotReachedNetShort(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndProvideLiquidity(lpTwo, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        // create user long position
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        uint256 proposedAmount = viewer.getLpProposedAmount(0, lpTwo, 1 ether, 100, [uint256(0), uint256(0)], 0);
        uint256 dy = viewer.getLpDy(0, lpTwo, 1 ether, [uint256(0), uint256(0)], proposedAmount);

        // should fail
        vm.expectRevert(abi.encodePacked("Amount is too small"));
        viewer.getLpProposedAmount(0, lpTwo, 1 ether, 100, [uint256(0), uint256(0)], dy + 1);

        // shouldn't fail
        viewer.getLpProposedAmount(0, lpTwo, 1 ether, 100, [uint256(0), uint256(0)], dy);
    }

    function testFuzz_FailsWhenLpMinAmountIsNotReachedNetLong(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 4);

        _dealAndProvideLiquidity(lp, tradeAmount * 2);
        _dealAndProvideLiquidity(lpTwo, tradeAmount * 2);
        _dealAndDeposit(trader, tradeAmount);

        // create user short position
        tradeAmount = tradeAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Short);
        vm.stopPrank();

        uint256 proposedAmount = viewer.getLpProposedAmount(0, lpTwo, 1 ether, 100, [uint256(0), uint256(0)], 0);
        uint256 dy = viewer.getLpDy(0, lpTwo, 1 ether, [uint256(0), uint256(0)], proposedAmount);

        // should fail
        vm.expectRevert(abi.encodePacked("Amount is too small"));
        viewer.getLpProposedAmount(0, lpTwo, 1 ether, 100, [uint256(0), uint256(0)], dy + 1);

        // shouldn't fail
        viewer.getLpProposedAmount(0, lpTwo, 1 ether, 100, [uint256(0), uint256(0)], dy);
    }

    function testFuzz_ReturnsCorrectUpdatedTwapValue(uint256 tradeAmount, uint256 durationPassed) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 4);
        durationPassed = bound(durationPassed, 0, vBase.heartBeat() - (block.timestamp - vBaseLastUpdate));
        _dealAndProvideLiquidity(lp, tradeAmount * 2);

        // create user position
        _dealAndDeposit(trader, tradeAmount);
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        vm.warp(block.timestamp + durationPassed);

        // get expected values
        (int256 eOracleTwap, int256 eMarketTwap) = viewer.getUpdatedTwap(0);

        // update twap
        clearingHouse.updateGlobalState();

        // assertions
        assertEq(eOracleTwap, perpetual.oracleTwap());
        assertEq(eMarketTwap, perpetual.marketTwap());
    }

    function testFuzz_ReturnsCorrectProceedsFromSwappingAfterRemovingLiquidity(uint256 tradeAmount) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 2);

        _dealAndProvideLiquidity(lp, tradeAmount);
        _dealAndProvideLiquidity(lpTwo, tradeAmount);

        uint256 proposedAmount = viewer.getLpProposedAmount(0, lpTwo, 1 ether, 100, [uint256(0), uint256(0)], 0);
        LibPerpetual.LiquidityProviderPosition memory lpPosition = viewer.getLpPosition(0, lpTwo);

        vm.warp(block.timestamp + perpetual.lockPeriod());

        vm.startPrank(lpTwo);
        clearingHouse.removeLiquidity(0, lpPosition.liquidityBalance, [uint256(0), uint256(0)], proposedAmount, 0);
        vm.stopPrank();
    }

    function testFuzz_canPredictFundingPaidByTraders(uint256 durationPassed, uint256 tradeAmount, bool goLong) public {
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 4);
        durationPassed = bound(durationPassed, 0, vBase.heartBeat() - (block.timestamp - vBaseLastUpdate));

        _dealAndProvideLiquidity(lp, tradeAmount * 2);
        _dealAndDeposit(trader, tradeAmount);

        // create user long position
        tradeAmount = goLong ? tradeAmount : tradeAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, goLong ? LibPerpetual.Side.Long : LibPerpetual.Side.Short);
        vm.stopPrank();

        vm.warp(block.timestamp + durationPassed);

        perpetual.updateGlobalState();
        int256 expectedFundingPaid = viewer.getTraderFundingPayments(0, trader);
        LibPerpetual.TraderPosition memory traderPosition = viewer.getTraderPosition(0, trader);
        LibPerpetual.GlobalPosition memory globalPosition = viewer.getGlobalPosition(0);

        vm.expectEmit(true, true, false, true);
        emit FundingPaid(
            trader, expectedFundingPaid, globalPosition.cumFundingRate, traderPosition.cumFundingRate, true
        );
        perpetual.__TestPerpetual__settleTraderWithUpdate(trader);
    }

    function testFuzz_canPredictFundingPaidByLPs(uint256 durationPassed, uint256 tradeAmount, bool goLong) public {
        uint256 heartBeat = vBase.heartBeat();
        tradeAmount = bound(tradeAmount, minTradeAmount * 2, maxTradeAmount / 4);
        durationPassed = bound(durationPassed, 0, vBase.heartBeat() - (block.timestamp - vBaseLastUpdate));

        durationPassed = heartBeat / 4;

        _dealAndProvideLiquidity(lp, tradeAmount * 2);
        _dealAndProvideLiquidity(lpTwo, tradeAmount);
        _dealAndDeposit(trader, tradeAmount);

        // create user long position
        tradeAmount = goLong ? tradeAmount : tradeAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, goLong ? LibPerpetual.Side.Long : LibPerpetual.Side.Short);
        vm.stopPrank();

        vm.warp(block.timestamp + durationPassed);

        perpetual.updateGlobalState();
        int256 expectedFundingPaid = viewer.getLpFundingPayments(0, lpTwo);
        LibPerpetual.LiquidityProviderPosition memory lpPosition = viewer.getLpPosition(0, lpTwo);
        LibPerpetual.GlobalPosition memory globalPosition = viewer.getGlobalPosition(0);

        vm.expectEmit(true, true, true, true);
        emit FundingPaid(
            lpTwo, expectedFundingPaid, globalPosition.cumFundingPerLpToken, lpPosition.cumFundingPerLpToken, false
        );
        perpetual.__TestPerpetual__settleLpWithUpdate(lpTwo);
    }
}
