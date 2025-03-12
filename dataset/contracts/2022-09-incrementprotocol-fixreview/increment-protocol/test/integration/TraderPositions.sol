// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

// contracts
import {Deployment} from "../helpers/Deployment.MainnetFork.sol";

// interfaces
import "../../contracts/interfaces/IClearingHouse.sol";

// libraries
import "../../contracts/lib/LibMath.sol";
import "../../contracts/lib/LibReserve.sol";
import "../../contracts/lib/LibPerpetual.sol";
import "../../lib/forge-std/src/StdError.sol";
import {console2 as console} from "../../lib/forge-std/src/console2.sol";

contract TraderPositions is Deployment {
    // libraries
    using LibMath for uint256;
    using LibMath for int256;

    // IClearingHouse events
    event ChangePosition(
        uint256 indexed idx,
        address indexed user,
        LibPerpetual.Side direction,
        int256 addedOpenNotional,
        int256 addedPositionSize,
        int256 profit,
        int256 tradingFeesPayed,
        int256 insuranceFeesPayed,
        bool isPositionIncreased,
        bool isPositionClosed
    );

    // IVault events
    event Deposit(address indexed user, address indexed asset, uint256 amount);

    // constants
    uint256 constant VQUOTE_INDEX = 0;
    uint256 constant VBASE_INDEX = 1;

    // addresses
    address lp = address(123);
    address lp2 = address(456);
    address alice = address(789);
    address bob = address(987);

    // config values
    uint256 maxTradeAmount;
    uint256 minTradeAmount;
    uint256 maxLiquidityAmount;
    int256 insuranceFee;
    uint24 usdcHeartBeat = 25 hours;
    uint256 vBaseLastUpdate;

    function _dealAndDeposit(address addr, uint256 amount) internal {
        deal(address(ua), addr, amount);

        vm.startPrank(addr);
        ua.approve(address(vault), amount);
        clearingHouse.deposit(amount, ua);
        vm.stopPrank();
    }

    function _dealAndApprove(address addr, uint256 amount) internal {
        deal(address(ua), addr, amount);

        vm.startPrank(addr);
        ua.approve(address(vault), amount);
        vm.stopPrank();
    }

    function _dealUSDCAndDeposit(address addr, uint256 amount) internal {
        bool isWhitelisted = vault.tokenToCollateralIdx(usdc) != 0;
        amount = LibReserve.wadToToken(usdc.decimals(), amount);

        if (!isWhitelisted) {
            vault.addWhiteListedCollateral(usdc, 1 ether, type(uint256).max);
            oracle.setOracle(address(usdc), usdcOracle, usdcHeartBeat, false);
        }

        deal(address(usdc), addr, amount);
        vm.startPrank(addr);
        usdc.approve(address(vault), amount);
        clearingHouse.deposit(amount, usdc);
        vm.stopPrank();
    }

    function _dealUSDCAndApprove(address addr, uint256 amount) internal {
        bool isWhitelisted = vault.tokenToCollateralIdx(usdc) != 0;
        amount = LibReserve.wadToToken(usdc.decimals(), amount);

        if (!isWhitelisted) {
            vault.addWhiteListedCollateral(usdc, 1 ether, type(uint256).max);
            oracle.setOracle(address(usdc), usdcOracle, usdcHeartBeat, false);
        }

        deal(address(usdc), addr, amount);
        vm.startPrank(addr);
        usdc.approve(address(vault), amount);
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

    function _getCloseTradeDirection(LibPerpetual.TraderPosition memory position)
        internal
        pure
        returns (LibPerpetual.Side)
    {
        return position.positionSize > 0 ? LibPerpetual.Side.Short : LibPerpetual.Side.Long;
    }

    function _revertLargeTrade(uint256 maxPosition, LibPerpetual.Side side) internal {
        _dealAndProvideLiquidity(bob, 10_000e18);
        _dealAndProvideLiquidity(lp, 10_000e18);
        _dealAndProvideLiquidity(lp2, 10_000e18);
        _dealAndDeposit(alice, 100e18);

        vm.startPrank(alice);
        vm.expectRevert(IPerpetual.Perpetual_MaxPositionSize.selector);
        // adding 2 to maxPosition is needed to exceed maxPositionSize on both forex and crypto pairs
        clearingHouse.changePosition(0, maxPosition + 2, 0, side);
    }

    function _openAndCheckPosition(
        LibPerpetual.Side direction,
        uint256 expectedTokensBought,
        uint256 minAmount,
        uint256 sellAmount
    ) internal {
        int256 initialVaultBalance = vault.getReserveValue(alice, false);
        console.log("reserve value: %s", initialVaultBalance);
        console.log("sell amount: %s", sellAmount);

        int256 positionSize;
        int256 notionalAmount;
        if (direction == LibPerpetual.Side.Long) {
            notionalAmount = sellAmount.toInt256() * -1;
            positionSize = expectedTokensBought.toInt256();
        } else {
            notionalAmount = expectedTokensBought.toInt256();
            positionSize = sellAmount.toInt256() * -1;
        }
        int256 eInsuranceFee = notionalAmount.abs().wadMul(insuranceFee);
        int256 percentageFee = curveCryptoViews.get_dy_fees_perc(
            cryptoSwap,
            direction == LibPerpetual.Side.Long ? VQUOTE_INDEX : VBASE_INDEX,
            direction == LibPerpetual.Side.Long ? VBASE_INDEX : VQUOTE_INDEX,
            sellAmount
        ).toInt256();
        int256 eTradingFee = notionalAmount.abs().wadMul(percentageFee);

        vm.startPrank(alice);
        vm.expectEmit(false, false, false, true);
        emit ChangePosition(
            0,
            alice,
            direction,
            notionalAmount,
            positionSize,
            (eInsuranceFee + eTradingFee) * -1,
            eTradingFee,
            eInsuranceFee,
            true,
            false
        );
        clearingHouse.changePosition(0, sellAmount, minAmount, direction);

        LibPerpetual.TraderPosition memory alicePosition = perpetual.getTraderPosition(alice);
        assertEq(alicePosition.positionSize, positionSize, "positionSize mismatch");
        assertEq(alicePosition.openNotional, notionalAmount, "openNotional mismatch");
        assertEq(alicePosition.cumFundingRate, 0, "cumFundingRate should be 0");

        LibPerpetual.GlobalPosition memory globalPosition = perpetual.getGlobalPosition();
        if (direction == LibPerpetual.Side.Long) {
            assertGe(alicePosition.positionSize, minAmount.toInt256(), "positionSize should be greater than minAmount");
            assertEq(int128(globalPosition.traderLongs), alicePosition.positionSize, "traderLongs mismatch");
            assertEq(globalPosition.traderShorts, 0, "traderShorts mismatch");
        } else {
            assertGe(alicePosition.openNotional, minAmount.toInt256(), "openNotional should be greater than minAmount");
            assertEq(
                int128(globalPosition.traderShorts), int256(alicePosition.positionSize).abs(), "traderShorts mismatch"
            );
            assertEq(globalPosition.traderLongs, 0, "traderLongs mismatch");
        }

        assertGt(
            int256(alicePosition.openNotional).abs().wadDiv(0.01 ether), 1, "openNotional should be greater than 0.01"
        );

        int256 vaultBalanceAfterPositionOpened = vault.getReserveValue(alice, false);
        int256 eNewVaultBalance = initialVaultBalance - eInsuranceFee - eTradingFee;
        assertEq(vaultBalanceAfterPositionOpened, eNewVaultBalance, "new vault balance mismatch");
    }

    function _updateTwap(LibPerpetual.GlobalPosition memory global, uint256 time)
        internal
        view
        returns (int256 marketTwap, int256 oracleTwap)
    {
        uint256 timeElapsed = time - global.timeOfLastTrade;

        /*
            priceCumulative1 = priceCumulative0 + price1 * timeElapsed
        */
        // will overflow in ~3000 years
        // update cumulative chainlink price feed
        uint256 latestChainlinkPrice = perpetual.indexPrice().toUint256();
        uint256 oracleCumulativeAmount =
            perpetual.oracleCumulativeAmount().toUint256() + latestChainlinkPrice * timeElapsed;

        // update cumulative market price feed
        uint256 latestMarketPrice = perpetual.marketPrice();
        uint256 marketCumulativeAmount =
            perpetual.marketCumulativeAmount().toUint256() + latestMarketPrice * timeElapsed;

        uint256 timeElapsedSinceBeginningOfPeriod = time - global.timeOfLastTwapUpdate;

        oracleTwap = perpetual.oracleTwap();
        marketTwap = perpetual.marketTwap();

        uint256 twapFrequency = perpetual.twapFrequency();
        if (timeElapsedSinceBeginningOfPeriod > twapFrequency) {
            int256 oracleCumulativeAmountAtBeginningOfPeriod = perpetual.oracleCumulativeAmountAtBeginningOfPeriod();
            int256 marketCumulativeAmountAtBeginningOfPeriod = perpetual.marketCumulativeAmountAtBeginningOfPeriod();
            /*
                TWAP = (priceCumulative1 - priceCumulative0) / timeElapsed
            */
            // calculate chainlink twap
            oracleTwap = (oracleCumulativeAmount.toInt256() - oracleCumulativeAmountAtBeginningOfPeriod)
                / timeElapsedSinceBeginningOfPeriod.toInt256();
            // calculate market twap
            marketTwap = (marketCumulativeAmount.toInt256() - marketCumulativeAmountAtBeginningOfPeriod)
                / timeElapsedSinceBeginningOfPeriod.toInt256();
        }
    }

    function _getExpectedTraderProfit(
        LibPerpetual.TraderPosition memory traderPosition,
        uint256 proposedAmount,
        uint256 buyIndex,
        uint256 sellIndex,
        bool long
    ) internal view returns (int256) {
        // calculate fees for closing position
        uint256 newPercentageFee = curveCryptoViews.get_dy_fees_perc(cryptoSwap, buyIndex, sellIndex, proposedAmount);
        uint256 newDyExFees = curveCryptoViews.get_dy_no_fee_deduct(cryptoSwap, buyIndex, sellIndex, proposedAmount);

        int256 quoteProceeds = long ? newDyExFees.toInt256() : proposedAmount.toInt256() * -1;
        int256 quoteOnlyFees = quoteProceeds.abs().wadMul(newPercentageFee.toInt256());
        return quoteProceeds + traderPosition.openNotional - quoteOnlyFees;
    }

    function _getExpectedFundingPayment(LibPerpetual.TraderPosition memory traderPosition, uint256 newTime, bool long)
        internal
        view
        returns (int256)
    {
        LibPerpetual.GlobalPosition memory globalPosition = viewer.getGlobalPosition(0);
        (int256 marketTwap, int256 oracleTwap) = _updateTwap(globalPosition, newTime);
        int256 sensitivity = perpetual.sensitivity();

        int256 currentTraderPremium = marketTwap - oracleTwap;
        uint256 timePassedSinceLastTrade = newTime - globalPosition.timeOfLastTrade;

        int256 fundingRate = sensitivity.wadMul(currentTraderPremium) * timePassedSinceLastTrade.toInt256() / 1 days;
        int256 globalCumFundingRate = globalPosition.cumFundingRate + fundingRate;

        int256 userCumFundingRate = traderPosition.cumFundingRate;
        if (userCumFundingRate != globalCumFundingRate) {
            int256 upcomingFundingRate =
                long ? userCumFundingRate - globalCumFundingRate : globalCumFundingRate - userCumFundingRate;
            return upcomingFundingRate.wadMul(int256(traderPosition.positionSize).abs());
        }
        return 0;
    }

    function setUp() public virtual override {
        super.setUp();
        maxTradeAmount = perpetual.maxPosition();
        minTradeAmount = clearingHouse.minPositiveOpenNotional();

        uint256 totalQuoteProvided = perpetual.getGlobalPosition().totalQuoteProvided;
        maxLiquidityAmount = perpetual.maxLiquidityProvided() - totalQuoteProvided;

        insuranceFee = perpetual.insuranceFee();

        (,,, vBaseLastUpdate,) = baseOracle.latestRoundData();
    }

    function testFuzz_FailsIfPoolHasNoLiquidity(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount, maxTradeAmount);
        _dealAndDeposit(alice, depositAmount);

        vm.startPrank(alice);
        vm.expectRevert(); // no error message from Curve
        clearingHouse.extendPositionWithCollateral(
            0, alice, depositAmount, ua, depositAmount / 10, LibPerpetual.Side.Long, 0
        );
    }

    function test_FailsIfAmountIsNull() public {
        vm.startPrank(alice);
        vm.expectRevert(IClearingHouse.ClearingHouse_ChangePositionZeroAmount.selector);
        clearingHouse.changePosition(0, 0, 0, LibPerpetual.Side.Long);
    }

    function testFuzz_FailsIfOpenNotionalUnderMinimumAllowedAmount(bool long) public {
        _dealAndProvideLiquidity(lp, minTradeAmount * 4);

        _dealAndDeposit(alice, minTradeAmount);

        uint256 quoteAmount = minTradeAmount - 1;
        uint256 baseAmount = curveCryptoViews.get_dy_no_fee_deduct(cryptoSwap, 1, 0, quoteAmount);

        vm.startPrank(alice);

        // Should fail with too little quote
        if (long) {
            vm.expectRevert(IClearingHouse.ClearingHouse_UnderOpenNotionalAmountRequired.selector);
            clearingHouse.changePosition(0, quoteAmount, 0, LibPerpetual.Side.Long);
        } else {
            // TODO: why isn't this reverting as expected?
            vm.expectRevert(IClearingHouse.ClearingHouse_UnderOpenNotionalAmountRequired.selector);
            clearingHouse.changePosition(0, baseAmount, 0, LibPerpetual.Side.Short);
        }

        // Should pass with just over the min quote
        quoteAmount = minTradeAmount + 1;
        baseAmount = curveCryptoViews.get_dx_ex_fees(cryptoSwap, 1, 0, quoteAmount);
        if (long) {
            clearingHouse.changePosition(0, quoteAmount, 0, LibPerpetual.Side.Long);
        } else {
            clearingHouse.changePosition(0, baseAmount, 0, LibPerpetual.Side.Short);
        }
    }

    function testFuzz_FailsIfUserHasTooLittleFunds(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount, maxTradeAmount / 20);
        _dealAndProvideLiquidity(lp, depositAmount * 2);

        _dealAndDeposit(alice, depositAmount);

        vm.startPrank(alice);
        vm.expectRevert(IClearingHouse.ClearingHouse_ExtendPositionInsufficientMargin.selector);
        clearingHouse.changePosition(0, depositAmount * 20, 0, LibPerpetual.Side.Long);
    }

    function test_RevertLargeLongPosition() public {
        uint256 maxPositionQuote = perpetual.maxPosition();
        _revertLargeTrade(maxPositionQuote, LibPerpetual.Side.Long);
    }

    function test_RevertLargeShortPosition() public {
        uint256 maxPositionBase = perpetual.maxPosition().wadDiv(perpetual.indexPrice().toUint256());
        _revertLargeTrade(maxPositionBase, LibPerpetual.Side.Short);
    }

    function testFuzz_OpenLongPosition(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount, maxTradeAmount);
        _dealAndProvideLiquidity(bob, depositAmount * 2);
        _dealAndDeposit(alice, depositAmount);

        uint256 expectedVBase = viewer.getTraderDy(0, depositAmount, LibPerpetual.Side.Long);
        uint256 minVBaseAmount = expectedVBase.wadMul(0.99 ether);
        uint256 expectedVBaseExFees = viewer.getExpectedVBaseAmountExFees(0, depositAmount);
        _openAndCheckPosition(LibPerpetual.Side.Long, expectedVBaseExFees, minVBaseAmount, depositAmount);
    }

    function testFuzz_OpenShortPosition(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount * 2, maxTradeAmount);
        _dealAndProvideLiquidity(bob, depositAmount * 2);
        _dealAndDeposit(alice, depositAmount);

        uint256 vBasePrice = perpetual.indexPrice().toUint256();
        uint256 sellAmount = depositAmount.wadDiv(vBasePrice);

        uint256 expectedVQuote = viewer.getTraderDy(0, sellAmount, LibPerpetual.Side.Short);
        uint256 minVQuoteAmount = expectedVQuote.wadMul(0.99 ether);
        uint256 expectedVQuoteExFees = viewer.getExpectedVQuoteAmountExFees(0, sellAmount);
        _openAndCheckPosition(LibPerpetual.Side.Short, expectedVQuoteExFees, minVQuoteAmount, sellAmount);
    }

    function testFuzz_OpenPositionAfterClosing(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount, maxTradeAmount);
        _dealAndProvideLiquidity(bob, depositAmount * 2);
        _dealAndApprove(alice, depositAmount);

        vm.startPrank(alice);
        clearingHouse.extendPositionWithCollateral(
            0, alice, depositAmount, ua, depositAmount, LibPerpetual.Side.Long, 0
        );

        LibPerpetual.TraderPosition memory alicePosition = perpetual.getTraderPosition(alice);

        clearingHouse.changePosition(
            0, int256(alicePosition.positionSize).toUint256(), 0, _getCloseTradeDirection(alicePosition)
        );

        // expected values
        int256 eInsuranceFee = depositAmount.toInt256().wadMul(insuranceFee);
        int256 percentageFee =
            curveCryptoViews.get_dy_fees_perc(cryptoSwap, VQUOTE_INDEX, VBASE_INDEX, depositAmount).toInt256();
        int256 eTradingFee = depositAmount.toInt256().wadMul(percentageFee);
        int256 eBaseProceeds = viewer.getExpectedVBaseAmountExFees(0, depositAmount).toInt256();

        vm.expectEmit(false, false, false, true);
        emit ChangePosition(
            0,
            alice,
            LibPerpetual.Side.Long,
            int256(depositAmount) * -1,
            eBaseProceeds,
            (eInsuranceFee + eTradingFee) * -1,
            eTradingFee,
            eInsuranceFee,
            true,
            false
        );
        clearingHouse.changePosition(0, depositAmount, 0, LibPerpetual.Side.Long);
    }

    function testFuzz_DepositAndOpenThenCloseAndWithdraw(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount * 2, maxTradeAmount);
        _dealAndProvideLiquidity(bob, depositAmount * 2);
        _dealAndApprove(alice, depositAmount);

        vm.startPrank(alice);

        // deposit collateral and open position
        int256 percentageFeeOpen =
            curveCryptoViews.get_dy_fees_perc(cryptoSwap, VQUOTE_INDEX, VBASE_INDEX, depositAmount).toInt256();
        clearingHouse.extendPositionWithCollateral(
            0, alice, depositAmount, ua, depositAmount, LibPerpetual.Side.Long, 0
        );

        LibPerpetual.TraderPosition memory alicePosition = perpetual.getTraderPosition(alice);

        int256 eInsuranceFee = int256(alicePosition.openNotional).abs().wadMul(insuranceFee);
        int256 eTradingFee = int256(alicePosition.openNotional).abs().wadMul(percentageFeeOpen);
        int256 eCollateralAmount = depositAmount.toInt256() - eInsuranceFee - eTradingFee;

        int256 alicePositionCollateralAfterPositionOpened = vault.getReserveValue(alice, false);
        assertEq(alicePositionCollateralAfterPositionOpened, eCollateralAmount, "collateral amount mismatch after open");

        // should fail to close position with insufficient proposedAmount
        uint256 insufficientProposedAmount = int256(alicePosition.positionSize).toUint256() / 2;
        vm.expectRevert(IClearingHouse.ClearingHouse_ClosePositionStillOpen.selector);
        clearingHouse.closePositionWithdrawCollateral(0, insufficientProposedAmount, 0, ua);

        // close position and withdraw collateral
        uint256 alicePositionSize = int256(alicePosition.positionSize).toUint256();
        clearingHouse.closePositionWithdrawCollateral(0, alicePositionSize, 0, ua);

        int256 alicePositionCollateralAfterPositionClosed = vault.getReserveValue(alice, false);
        assertEq(alicePositionCollateralAfterPositionClosed, 0, "collateral amount mismatch after close");
    }

    function testFuzz_FailsToWithdrawCollateralOutsideMarginRequirement(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount, maxTradeAmount);
        _dealAndProvideLiquidity(bob, depositAmount * 2);
        _dealAndApprove(alice, depositAmount);

        vm.startPrank(alice);
        clearingHouse.extendPositionWithCollateral(
            0, alice, depositAmount, ua, depositAmount, LibPerpetual.Side.Long, 0
        );

        uint256 aliceUABalance = vault.getBalance(alice, 0).toUint256();
        assertGt(aliceUABalance, 0, "Alice's UA balance in vault should be greater than 0");

        vm.expectRevert(IClearingHouse.ClearingHouse_WithdrawInsufficientMargin.selector);
        clearingHouse.withdraw(aliceUABalance, ua);

        vm.expectRevert(IClearingHouse.ClearingHouse_WithdrawInsufficientMargin.selector);
        clearingHouse.withdrawAll(ua);
    }

    function testFuzz_IncreasePositionWithSufficientCollateral(uint256 depositAmount, bool long) public {
        depositAmount = bound(depositAmount, minTradeAmount * 20, maxTradeAmount);
        _dealAndProvideLiquidity(bob, depositAmount * 2);
        _dealAndApprove(alice, depositAmount);

        LibPerpetual.Side direction = long ? LibPerpetual.Side.Long : LibPerpetual.Side.Short;

        LibPerpetual.TraderPosition memory traderPositionBeforeFirstTrade = viewer.getTraderPosition(0, alice);
        assertEq(traderPositionBeforeFirstTrade.openNotional, 0, "openNotional should be 0 before first trade");
        assertEq(traderPositionBeforeFirstTrade.positionSize, 0, "positionSize should be 0 before first trade");
        assertEq(traderPositionBeforeFirstTrade.cumFundingRate, 0, "cumFundingRate should be 0 before first trade");

        uint256 sellAmount;
        if (direction == LibPerpetual.Side.Long) {
            sellAmount = depositAmount / 10;
        } else {
            uint256 vBasePrice = perpetual.indexPrice().toUint256();
            sellAmount = (depositAmount / 10).wadDiv(vBasePrice);
        }
        vm.assume(sellAmount >= minTradeAmount);

        // position is 10% of the collateral
        uint256 eReceived1 = curveCryptoViews.get_dy_no_fee_deduct(
            cryptoSwap,
            direction == LibPerpetual.Side.Long ? VQUOTE_INDEX : VBASE_INDEX,
            direction == LibPerpetual.Side.Long ? VBASE_INDEX : VQUOTE_INDEX,
            sellAmount
        );
        vm.startPrank(alice);
        clearingHouse.extendPositionWithCollateral(0, alice, depositAmount, ua, sellAmount, direction, 0);

        // check trader position
        LibPerpetual.TraderPosition memory traderPositionAfterFirstTrade = viewer.getTraderPosition(0, alice);
        if (direction == LibPerpetual.Side.Long) {
            assertEq(
                traderPositionAfterFirstTrade.positionSize,
                eReceived1.toInt256(),
                "positionSize mismatch after first trade: long"
            );
            assertEq(
                traderPositionAfterFirstTrade.openNotional,
                sellAmount.toInt256() * -1,
                "openNotional mismatch after first trade: long"
            );
        } else {
            assertEq(
                traderPositionAfterFirstTrade.openNotional,
                eReceived1.toInt256(),
                "openNotional mismatch after first trade: short"
            );
            assertEq(
                traderPositionAfterFirstTrade.positionSize,
                sellAmount.toInt256() * -1,
                "positionSize mismatch after first trade: short"
            );
        }
        assertEq(traderPositionAfterFirstTrade.cumFundingRate, 0, "cumFundingRate should be 0 after first trade");

        int256 vaultBalanceAfterFirstTrade = vault.getReserveValue(alice, false);

        // change the value of global.cumFundingRate to force a funding rate payment when extending the position
        uint256 anteriorTimestamp = block.timestamp - 15;
        int256 newCumFundingRate;
        if (direction == LibPerpetual.Side.Long) {
            // set very large positive cumFundingRate so that LONG position is impacted negatively
            newCumFundingRate = 0.1 ether;
        } else {
            // set very large negative cumFundingRate so that SHORT position is impacted negatively
            newCumFundingRate = -0.1 ether;
        }
        perpetual.__TestPerpetual__setGlobalPositionFundingRate(uint64(anteriorTimestamp), int128(newCumFundingRate));

        if (direction == LibPerpetual.Side.Long) {
            sellAmount = depositAmount / 10;
        } else {
            uint256 vBasePrice = perpetual.indexPrice().toUint256();
            sellAmount = (depositAmount / 10).wadDiv(vBasePrice);
        }

        // total position is 20% of the collateral
        uint256 eReceived2 = curveCryptoViews.get_dy_no_fee_deduct(
            cryptoSwap,
            direction == LibPerpetual.Side.Long ? VQUOTE_INDEX : VBASE_INDEX,
            direction == LibPerpetual.Side.Long ? VBASE_INDEX : VQUOTE_INDEX,
            sellAmount
        );
        int256 percentageFee = curveCryptoViews.get_dy_fees_perc(
            cryptoSwap,
            direction == LibPerpetual.Side.Long ? VQUOTE_INDEX : VBASE_INDEX,
            direction == LibPerpetual.Side.Long ? VBASE_INDEX : VQUOTE_INDEX,
            sellAmount
        ).toInt256();
        clearingHouse.changePosition(0, sellAmount, 0, direction);

        // check trader position
        LibPerpetual.TraderPosition memory traderPositionAfterSecondTrade = viewer.getTraderPosition(0, alice);
        if (direction == LibPerpetual.Side.Long) {
            assertEq(
                traderPositionAfterSecondTrade.positionSize,
                traderPositionAfterFirstTrade.positionSize + eReceived2.toInt256(),
                "positionSize mismatch after second trade: long"
            );
            assertEq(
                traderPositionAfterSecondTrade.openNotional,
                traderPositionAfterFirstTrade.openNotional * 2,
                "openNotional mismatch after second trade: long"
            );
        } else {
            assertEq(
                traderPositionAfterSecondTrade.openNotional,
                traderPositionAfterFirstTrade.openNotional + eReceived2.toInt256(),
                "openNotional mismatch after second trade: short"
            );
            assertEq(
                traderPositionAfterSecondTrade.positionSize,
                traderPositionAfterFirstTrade.positionSize * 2,
                "positionSize mismatch after second trade: short"
            );
        }

        int256 vaultBalanceAfterSecondTrade = vault.getReserveValue(alice, false);

        // expected vault after expansion of position
        int256 eUpcomingFundingRate;
        if (direction == LibPerpetual.Side.Long) {
            eUpcomingFundingRate =
                traderPositionAfterFirstTrade.cumFundingRate - perpetual.getGlobalPosition().cumFundingRate;
        } else {
            eUpcomingFundingRate =
                perpetual.getGlobalPosition().cumFundingRate - traderPositionAfterFirstTrade.cumFundingRate;
        }
        int256 eFundingPayment = eUpcomingFundingRate.wadMul(int256(traderPositionAfterFirstTrade.positionSize).abs());
        int256 addedOpenNotional = int256(traderPositionAfterSecondTrade.openNotional).abs()
            - int256(traderPositionAfterFirstTrade.openNotional).abs();
        int256 eInsuranceFee = addedOpenNotional.wadMul(insuranceFee);
        int256 eTradingFee = addedOpenNotional.wadMul(percentageFee);
        int256 eNewVaultBalance = vaultBalanceAfterFirstTrade + eFundingPayment - eInsuranceFee - eTradingFee;
        assertApproxEqAbs(eNewVaultBalance, vaultBalanceAfterSecondTrade, 1, "new vault balance mismatch");
        assertLt(vaultBalanceAfterSecondTrade, vaultBalanceAfterFirstTrade, "vault balance should decrease");

        uint256 proposedAmount = viewer.getTraderProposedAmount(0, alice, 1e18, 100, 0);
        clearingHouse.changePosition(0, proposedAmount, 0, _getCloseTradeDirection(traderPositionAfterSecondTrade));

        // check trader position
        LibPerpetual.TraderPosition memory traderPositionAfterClosingPosition = viewer.getTraderPosition(0, alice);
        assertEq(traderPositionAfterClosingPosition.positionSize, 0, "positionSize mismatch after closing position");
        assertEq(traderPositionAfterClosingPosition.openNotional, 0, "openNotional mismatch after closing position");
        assertEq(
            traderPositionAfterClosingPosition.cumFundingRate, 0, "cumFundingRate should be 0 after closing position"
        );
    }

    function testFuzz_FailsToIncreasePositionOutsideMargin(uint256 depositAmount, bool long) public {
        depositAmount = bound(depositAmount, minTradeAmount, maxTradeAmount / 30);
        _dealAndProvideLiquidity(bob, depositAmount * 20);
        _dealAndProvideLiquidity(lp, depositAmount * 20);
        _dealAndProvideLiquidity(lp2, depositAmount * 20);
        _dealAndApprove(alice, depositAmount);

        LibPerpetual.Side direction = long ? LibPerpetual.Side.Long : LibPerpetual.Side.Short;
        uint256 sellAmount;
        if (direction == LibPerpetual.Side.Long) {
            sellAmount = depositAmount;
        } else {
            uint256 vBasePrice = perpetual.indexPrice().toUint256();
            sellAmount = depositAmount.wadDiv(vBasePrice);
        }
        vm.assume(sellAmount >= minTradeAmount);

        // position is within margin ratio
        vm.startPrank(alice);
        clearingHouse.extendPositionWithCollateral(0, alice, depositAmount, ua, sellAmount, direction, 0);

        uint256 newSellAmount;
        if (direction == LibPerpetual.Side.Long) {
            newSellAmount = depositAmount * 15;
        } else {
            uint256 vBasePrice = perpetual.indexPrice().toUint256();
            newSellAmount = (depositAmount * 15).wadDiv(vBasePrice);
        }

        // new position is outside margin ratio
        vm.expectRevert(IClearingHouse.ClearingHouse_ExtendPositionInsufficientMargin.selector);
        clearingHouse.changePosition(0, newSellAmount, 0, direction);
    }

    function test_FailsToClosePositionWithNullProposedAmount() public {
        vm.startPrank(alice);
        vm.expectRevert(IClearingHouse.ClearingHouse_ChangePositionZeroAmount.selector);
        clearingHouse.changePosition(0, 0, 0, LibPerpetual.Side.Long);
        vm.expectRevert(IClearingHouse.ClearingHouse_ChangePositionZeroAmount.selector);
        clearingHouse.changePosition(0, 0, 0, LibPerpetual.Side.Short);
    }

    function testFuzz_EntirelyClosedLongPositionShouldReturnExpectedProfit(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount * 20, maxTradeAmount);
        // note: no funding payments involved in the profit
        _dealAndProvideLiquidity(bob, depositAmount * 2);
        _dealAndDeposit(alice, depositAmount);

        vm.startPrank(alice);

        int256 initialVaultBalance = vault.getReserveValue(alice, false);
        uint256 vQuoteLiquidityBeforePositionCreated = cryptoSwap.balances(VQUOTE_INDEX);
        uint256 percentageFeeStart =
            curveCryptoViews.get_dy_fees_perc(cryptoSwap, VQUOTE_INDEX, VBASE_INDEX, depositAmount / 10);

        clearingHouse.changePosition(0, depositAmount / 10, 0, LibPerpetual.Side.Long);

        // check intermediate vault balance
        LibPerpetual.TraderPosition memory alicePositionBeforeClosingPosition = perpetual.getTraderPosition(alice);
        int256 eInsurancePaid = (depositAmount / 10).toInt256().wadMul(insuranceFee);
        int256 eTradingFeesOpenPosition = (depositAmount / 10).wadMul(percentageFeeStart).toInt256();
        assertEq(
            vault.getReserveValue(alice, false),
            initialVaultBalance - eInsurancePaid - eTradingFeesOpenPosition,
            "vault balance mismatch after opening position"
        );

        // check intermediate VQuote liquidity
        assertEq(
            cryptoSwap.balances(VQUOTE_INDEX),
            vQuoteLiquidityBeforePositionCreated + (depositAmount / 10),
            "VQuote liquidity mismatch after opening position"
        );

        // sell the entire position, i.e. user.positionSize
        int256 dyExFees = curveCryptoViews.get_dy_no_fee_deduct(
            cryptoSwap, VBASE_INDEX, VQUOTE_INDEX, int256(alicePositionBeforeClosingPosition.positionSize).toUint256()
        ).toInt256();
        int256 percentageFee = curveCryptoViews.get_dy_fees_perc(
            cryptoSwap, VBASE_INDEX, VQUOTE_INDEX, int256(alicePositionBeforeClosingPosition.positionSize).toUint256()
        ).toInt256();
        clearingHouse.changePosition(
            0,
            int256(alicePositionBeforeClosingPosition.positionSize).toUint256(),
            0,
            _getCloseTradeDirection(alicePositionBeforeClosingPosition)
        );

        // check final vault balance
        int256 expectedProfit = dyExFees + alicePositionBeforeClosingPosition.openNotional;
        console.log("expectedProfit: %s", expectedProfit);
        int256 eTradingFeesClosePosition = dyExFees.wadMul(percentageFee);
        assertEq(
            vault.getReserveValue(alice, false),
            initialVaultBalance + expectedProfit - eInsurancePaid - eTradingFeesOpenPosition - eTradingFeesClosePosition,
            "vault balance mismatch after closing position"
        );

        // when a position is entirely closed, it is deleted
        LibPerpetual.TraderPosition memory alicePositionAfterClosingPosition = perpetual.getTraderPosition(alice);
        assertEq(alicePositionAfterClosingPosition.positionSize, 0, "positionSize mismatch after closing position");
        assertEq(alicePositionAfterClosingPosition.openNotional, 0, "openNotional mismatch after closing position");
        assertEq(alicePositionAfterClosingPosition.cumFundingRate, 0, "cumFundingRate mismatch after closing position");
    }

    function testFuzz_EntirelyClosedShortPositionShouldReturnExpectedProfit(uint256 depositAmount) public {
        // note: no funding payments involved in the profit
        depositAmount = bound(depositAmount, minTradeAmount * 20, maxTradeAmount);
        _dealAndProvideLiquidity(bob, depositAmount * 2);
        _dealAndDeposit(alice, depositAmount);

        vm.startPrank(alice);

        int256 initialVaultBalance = vault.getReserveValue(alice, false);
        LibPerpetual.TraderPosition memory alicePositionBeforeClosingPosition;
        int256 aliceOpenNotional;
        int256 eInsurancePaid;
        int256 eTradingFeesOpenPosition;
        {
            uint256 vQuoteLiquidityBeforePositionCreated = cryptoSwap.balances(VQUOTE_INDEX);
            uint256 positionAmount = (depositAmount / 10).wadDiv(perpetual.indexPrice().toUint256());
            uint256 dyInclFees = curveCryptoViews.get_dy(cryptoSwap, VBASE_INDEX, VQUOTE_INDEX, positionAmount);
            int256 percentageFeeStart =
                curveCryptoViews.get_dy_fees_perc(cryptoSwap, VBASE_INDEX, VQUOTE_INDEX, positionAmount).toInt256();

            clearingHouse.changePosition(0, positionAmount, 0, LibPerpetual.Side.Short);

            // check intermediate vault balance
            alicePositionBeforeClosingPosition = perpetual.getTraderPosition(alice);
            aliceOpenNotional = int256(alicePositionBeforeClosingPosition.openNotional);
            eInsurancePaid = aliceOpenNotional.wadMul(insuranceFee);
            eTradingFeesOpenPosition = aliceOpenNotional.wadMul(percentageFeeStart);
            assertEq(
                vault.getReserveValue(alice, false),
                initialVaultBalance - eInsurancePaid - eTradingFeesOpenPosition,
                "vault balance mismatch after opening position"
            );

            // check intermediate VQuote liquidity
            assertEq(
                cryptoSwap.balances(VQUOTE_INDEX),
                vQuoteLiquidityBeforePositionCreated - dyInclFees,
                "VQuote liquidity mismatch after opening position"
            );
        }

        // sell the entire position
        uint256 proposedAmount = viewer.getTraderProposedAmount(0, alice, 1e18, 100, 0);
        int256 percentageFee =
            curveCryptoViews.get_dy_fees_perc(cryptoSwap, VQUOTE_INDEX, VBASE_INDEX, proposedAmount).toInt256();
        int256 quoteProceeds = proposedAmount.toInt256() * -1;
        clearingHouse.changePosition(0, proposedAmount, 0, _getCloseTradeDirection(alicePositionBeforeClosingPosition));

        // check final vault balance
        int256 eVQuoteReceived = quoteProceeds - quoteProceeds.abs().wadMul(percentageFee);
        int256 expectedProfit = eVQuoteReceived + aliceOpenNotional;
        assertEq(
            vault.getReserveValue(alice, false),
            initialVaultBalance + expectedProfit - eInsurancePaid - eTradingFeesOpenPosition,
            "vault balance mismatch after closing position"
        );

        // when a position is entirely closed, it is deleted
        LibPerpetual.TraderPosition memory alicePositionAfterClosingPosition = perpetual.getTraderPosition(alice);
        assertEq(alicePositionAfterClosingPosition.positionSize, 0, "positionSize mismatch after closing position");
        assertEq(alicePositionAfterClosingPosition.openNotional, 0, "openNotional mismatch after closing position");
        assertEq(alicePositionAfterClosingPosition.cumFundingRate, 0, "cumFundingRate mismatch after closing position");
    }

    function testFuzz_ReducePositionByReductionFactor(uint256 depositAmount, uint256 reductionFactor, bool long)
        public
    {
        depositAmount = bound(depositAmount, minTradeAmount * 20, maxTradeAmount);
        reductionFactor = bound(reductionFactor, 1e16, 8e17);
        LibPerpetual.Side direction = long ? LibPerpetual.Side.Long : LibPerpetual.Side.Short;

        _dealAndProvideLiquidity(bob, depositAmount * 2);
        _dealAndApprove(alice, depositAmount);

        vm.startPrank(alice);

        LibPerpetual.TraderPosition memory traderPosition = viewer.getTraderPosition(0, alice);
        assertEq(traderPosition.positionSize, 0, "positionSize should be 0 before first trade");
        assertEq(traderPosition.openNotional, 0, "openNotional should be 0 before first trade");
        assertEq(traderPosition.cumFundingRate, 0, "cumFundingRate should be 0 before first trade");

        // position is 10% of the collateral
        uint256 positionAmount;
        if (direction == LibPerpetual.Side.Long) {
            positionAmount = depositAmount / 10;
        } else {
            uint256 vBasePrice = perpetual.indexPrice().toUint256();
            positionAmount = (depositAmount / 10).wadDiv(vBasePrice);
        }

        vm.assume(positionAmount >= minTradeAmount);
        clearingHouse.extendPositionWithCollateral(0, alice, depositAmount, ua, positionAmount, direction, 0);

        // check trader position
        traderPosition = viewer.getTraderPosition(0, alice);
        if (direction == LibPerpetual.Side.Long) {
            assertGt(traderPosition.positionSize, 0, "positionSize mismatch after first trade: long");
            assertEq(
                traderPosition.openNotional,
                positionAmount.toInt256() * -1,
                "openNotional mismatch after first trade: long"
            );
        } else {
            assertLt(traderPosition.positionSize, 0, "positionSize mismatch after first trade: short");
            assertGt(traderPosition.openNotional, 0, "openNotional mismatch after first trade: short");
        }
        assertEq(traderPosition.cumFundingRate, 0, "cumFundingRate should be 0 after first trade");

        // check under open notional requirement
        bool isUnderOpenNotionalRequirement;
        uint256 proposedAmount = viewer.getTraderProposedAmount(0, alice, reductionFactor, 100, 0);

        int256 baseProceeds;

        if (direction == LibPerpetual.Side.Long) {
            baseProceeds = -(proposedAmount.toInt256());
        } else {
            baseProceeds = curveCryptoViews.get_dy_no_fee_deduct(cryptoSwap, 0, 1, proposedAmount).toInt256();
        }

        uint256 realizedReductionRatio =
            (baseProceeds.abs().wadDiv(int256(traderPosition.positionSize).abs())).toUint256();
        int256 addedOpenNotional = int256(-traderPosition.openNotional).wadMul(realizedReductionRatio.toInt256());
        isUnderOpenNotionalRequirement =
            (int256(traderPosition.openNotional) + addedOpenNotional).abs() < minTradeAmount.toInt256();

        // reduce position should fail if under open notional requirement, otherwise it should succeed
        if (isUnderOpenNotionalRequirement) {
            vm.expectRevert(IClearingHouse.ClearingHouse_UnderOpenNotionalAmountRequired.selector);
            clearingHouse.changePosition(0, proposedAmount, 0, _getCloseTradeDirection(traderPosition));
        } else {
            clearingHouse.changePosition(0, proposedAmount, 0, _getCloseTradeDirection(traderPosition));
            // check trader position
            LibPerpetual.TraderPosition memory traderPositionAfterReducingPosition = viewer.getTraderPosition(0, alice);
            assertEq(
                traderPositionAfterReducingPosition.positionSize,
                traderPosition.positionSize + baseProceeds,
                "positionSize mismatch after reducing position"
            );
            assertEq(
                traderPositionAfterReducingPosition.openNotional,
                traderPosition.openNotional + addedOpenNotional,
                "openNotional mismatch after reducing position"
            );
            assertEq(
                traderPositionAfterReducingPosition.cumFundingRate, 0, "cumFundingRate mismatch after reducing position"
            );
        }
    }

    function testFuzz_FailsIfGreaterThanMaxBlockTradeAmount(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount * 10, maxTradeAmount / 20);
        _dealAndProvideLiquidity(bob, depositAmount * 20);
        _dealAndApprove(alice, depositAmount * 20);

        vm.startPrank(alice);

        uint256 maxBlockTradeAmount = perpetual.maxBlockTradeAmount();
        vm.expectRevert(IPerpetual.Perpetual_ExcessiveBlockTradeAmount.selector);
        clearingHouse.extendPositionWithCollateral(
            0, alice, depositAmount * 20, ua, maxBlockTradeAmount, LibPerpetual.Side.Long, 0
        );
    }

    function testFuzz_FailsIfCollectivelyGreaterThanMaxBlockTradeAmount(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount * 10, maxTradeAmount / 20);
        _dealAndProvideLiquidity(lp, depositAmount * 20);
        _dealAndProvideLiquidity(lp2, depositAmount * 20);
        _dealAndApprove(alice, depositAmount * 20);

        vm.startPrank(alice);

        uint256 maxBlockTradeAmount = perpetual.maxBlockTradeAmount();
        uint256 firstTradePositionAmount = depositAmount * 10;
        uint256 secondTradePositionAmount = maxBlockTradeAmount - firstTradePositionAmount;

        vm.expectEmit(false, false, false, false); // do not check event data
        emit ChangePosition(0, alice, LibPerpetual.Side.Long, 0, 0, 0, 0, 0, false, false);
        clearingHouse.extendPositionWithCollateral(
            0, alice, depositAmount * 10, ua, firstTradePositionAmount, LibPerpetual.Side.Long, 0
        );

        vm.expectRevert(IPerpetual.Perpetual_ExcessiveBlockTradeAmount.selector);
        clearingHouse.extendPositionWithCollateral(
            0, alice, depositAmount * 10, ua, secondTradePositionAmount, LibPerpetual.Side.Long, 0
        );
    }

    function test_UpdateAndCheckBlockTradeAmount() public {
        uint256 maxBlockTradeAmount = perpetual.maxBlockTradeAmount();

        perpetual.__TestPerpetual__updateCurrentBlockTradeAmount(maxBlockTradeAmount);
        assertEq(
            perpetual.__TestPerpetual__checkBlockTradeAmount(),
            false,
            "_checkBlockTradeAmount should return false if current block trade amount is equal to max"
        );
        perpetual.__TestPerpetual__resetCurrentBlockTradeAmount();

        perpetual.__TestPerpetual__updateCurrentBlockTradeAmount(maxBlockTradeAmount - 1);
        assertTrue(
            perpetual.__TestPerpetual__checkBlockTradeAmount(),
            "_checkBlockTradeAmount should return true if current block trade amount is less than max"
        );
        perpetual.__TestPerpetual__resetCurrentBlockTradeAmount();
    }

    function testFuzz_FailsIfMinAmountNotReached(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount, maxTradeAmount / 2);
        _dealAndProvideLiquidity(bob, depositAmount * 2);
        _dealAndApprove(alice, depositAmount);

        vm.startPrank(alice);

        uint256 dyExFees = curveCryptoViews.get_dy_no_fee_deduct(cryptoSwap, VQUOTE_INDEX, VBASE_INDEX, depositAmount);
        uint256 dyInclFees = curveCryptoViews.get_dy(cryptoSwap, VQUOTE_INDEX, VBASE_INDEX, depositAmount);

        vm.expectRevert("Slippage");
        clearingHouse.extendPositionWithCollateral(
            0, alice, depositAmount, ua, depositAmount, LibPerpetual.Side.Long, dyInclFees + 1
        );

        vm.expectEmit(false, false, false, false); // do not check event data
        emit ChangePosition(0, alice, LibPerpetual.Side.Long, 0, 0, 0, 0, 0, false, false);
        clearingHouse.extendPositionWithCollateral(
            0, alice, depositAmount, ua, depositAmount, LibPerpetual.Side.Long, dyInclFees
        );

        assertEq(
            int256(perpetual.getTraderPosition(alice).positionSize).toUint256(),
            dyExFees,
            "positionSize should be equal to dyExFees"
        );
    }

    function testFuzz_ReimburseTradingFeesPaid(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount, maxTradeAmount / 20);
        _dealAndProvideLiquidity(bob, depositAmount * 20);
        _dealAndApprove(alice, depositAmount);

        vm.startPrank(alice);

        uint256 dyExFees = curveCryptoViews.get_dy_no_fee_deduct(cryptoSwap, VQUOTE_INDEX, VBASE_INDEX, depositAmount);
        uint256 dyInclFees = curveCryptoViews.get_dy(cryptoSwap, VQUOTE_INDEX, VBASE_INDEX, depositAmount);

        // position is within the margin ratio
        clearingHouse.extendPositionWithCollateral(
            0, alice, depositAmount, ua, depositAmount, LibPerpetual.Side.Long, 0
        );

        LibPerpetual.TraderPosition memory traderPosition = viewer.getTraderPosition(0, alice);
        LibPerpetual.GlobalPosition memory globalPosition = viewer.getGlobalPosition(0);
        uint256 totalBaseSupply = vBase.totalSupply();

        assertEq(traderPosition.openNotional, int256(depositAmount) * -1, "openNotional mismatch");
        assertEq(globalPosition.totalQuoteFeesGrowth, 0, "totalQuoteFeesGrowth mismatch");
        assertEq(
            globalPosition.totalBaseFeesGrowth,
            (dyExFees - dyInclFees).wadDiv(totalBaseSupply),
            "totalBaseFeesGrowth mismatch"
        );
    }

    function testFuzz_ReversePosition(uint256 depositAmount, bool long) public {
        depositAmount = bound(depositAmount, minTradeAmount * 4, maxTradeAmount / 2);
        _dealAndProvideLiquidity(bob, depositAmount * 20);
        _dealAndApprove(alice, depositAmount * 20);
        LibPerpetual.Side direction = long ? LibPerpetual.Side.Long : LibPerpetual.Side.Short;

        vm.startPrank(alice);

        uint256 initialPositionAmount;
        if (direction == LibPerpetual.Side.Long) {
            initialPositionAmount = depositAmount;
        } else {
            uint256 vBasePrice = perpetual.indexPrice().toUint256();
            initialPositionAmount = depositAmount.wadDiv(vBasePrice);
        }
        clearingHouse.extendPositionWithCollateral(0, alice, depositAmount, ua, initialPositionAmount, direction, 0);

        // check initial position
        LibPerpetual.TraderPosition memory traderPositionBefore = viewer.getTraderPosition(0, alice);
        if (direction == LibPerpetual.Side.Long) {
            assertGt(
                traderPositionBefore.positionSize, 0, "positionSize should be greater than 0 after first trade: long"
            );
        } else {
            assertLt(
                traderPositionBefore.positionSize, 0, "positionSize should be less than 0 after first trade: short"
            );
        }

        uint256 newPositionAmount;
        LibPerpetual.Side newDirection = long ? LibPerpetual.Side.Short : LibPerpetual.Side.Long;
        if (newDirection == LibPerpetual.Side.Long) {
            newPositionAmount = depositAmount * 2;
        } else {
            uint256 vBasePrice = perpetual.indexPrice().toUint256();
            newPositionAmount = (depositAmount * 2).wadDiv(vBasePrice);
        }

        // should not reverse position with changePosition function
        vm.expectRevert(IPerpetual.Perpetual_AttemptReversePosition.selector);
        clearingHouse.changePosition(0, newPositionAmount, 0, newDirection);

        // should fail to reverse position with insufficient proposedAmount
        {
            uint256 insufficientCloseProposedAmount = viewer.getTraderProposedAmount(0, alice, 1e18, 100, 0) / 2;
            vm.expectRevert(IClearingHouse.ClearingHouse_ClosePositionStillOpen.selector);
            clearingHouse.openReversePosition(0, insufficientCloseProposedAmount, 0, newPositionAmount, 0, newDirection);
        }

        // should reverse position with openReversePosition function
        uint256 closeProposedAmount = viewer.getTraderProposedAmount(0, alice, 1e18, 100, 0);
        clearingHouse.openReversePosition(0, closeProposedAmount, 0, newPositionAmount, 0, newDirection);

        // check final position
        LibPerpetual.TraderPosition memory traderPositionAfter = viewer.getTraderPosition(0, alice);
        if (newDirection == LibPerpetual.Side.Long) {
            assertGt(
                traderPositionAfter.positionSize,
                0,
                "positionSize should be greater than 0 after reversing position: short to long"
            );
            assertEq(
                traderPositionAfter.openNotional,
                newPositionAmount.toInt256() * -1,
                "openNotional mismatch after reversing position: short to long"
            );
        } else {
            assertEq(
                traderPositionAfter.positionSize,
                newPositionAmount.toInt256() * -1,
                "positionSize mismatch after reversing position: long to short"
            );
            assertGt(
                traderPositionAfter.openNotional,
                0,
                "openNotional should be greater than 0 after reversing position: long to short"
            );
        }
    }

    function testFuzz_InitializeUserFundingRateIndex(uint256 depositAmount, bool long) public {
        depositAmount = bound(depositAmount, minTradeAmount * 2, maxTradeAmount);
        _dealAndProvideLiquidity(bob, depositAmount * 20);
        _dealAndApprove(alice, depositAmount);
        LibPerpetual.Side direction = long ? LibPerpetual.Side.Long : LibPerpetual.Side.Short;

        uint256 positionAmount;
        if (direction == LibPerpetual.Side.Long) {
            positionAmount = depositAmount;
        } else {
            uint256 vBasePrice = perpetual.indexPrice().toUint256();
            positionAmount = depositAmount.wadDiv(vBasePrice);
        }

        perpetual.__TestPerpetual__setGlobalPositionFundingRate(block.timestamp.toUint64(), 10);

        // open position
        vm.startPrank(alice);
        clearingHouse.extendPositionWithCollateral(0, alice, depositAmount, ua, positionAmount, direction, 0);
        assertEq(
            perpetual.getTraderPosition(alice).cumFundingRate, 10, "cumFundingRate mismatch after opening position"
        );
    }

    function testFuzz_CorrectlyCalculatesTraderProfits(uint256 depositAmount, uint256 durationPassed, bool long)
        public
    {
        // TODO: resolve intermittant VBase_DataNotFresh error
        depositAmount = bound(depositAmount, minTradeAmount * 2, maxTradeAmount);
        durationPassed = bound(durationPassed, 1 minutes, vBase.heartBeat() - (block.timestamp - vBaseLastUpdate));
        _dealAndProvideLiquidity(bob, depositAmount * 20);
        _dealAndApprove(alice, depositAmount);

        LibPerpetual.Side direction = long ? LibPerpetual.Side.Long : LibPerpetual.Side.Short;

        uint256 balanceBefore = ua.balanceOf(alice);

        // determine position amount depending on direction
        uint256 positionAmount;
        if (direction == LibPerpetual.Side.Long) {
            positionAmount = depositAmount;
        } else {
            uint256 vBasePrice = perpetual.indexPrice().toUint256();
            positionAmount = depositAmount.wadDiv(vBasePrice);
        }

        // calculate fees for opening position
        uint256 dyExFees = curveCryptoViews.get_dy_no_fee_deduct(
            cryptoSwap, long ? VQUOTE_INDEX : VBASE_INDEX, long ? VBASE_INDEX : VQUOTE_INDEX, positionAmount
        );
        int256 tradingFees = (long ? positionAmount : dyExFees).wadMul(
            curveCryptoViews.get_dy_fees_perc(
                cryptoSwap, long ? VQUOTE_INDEX : VBASE_INDEX, long ? VBASE_INDEX : VQUOTE_INDEX, positionAmount
            )
        ).toInt256();
        int256 insuranceFees = (long ? positionAmount : dyExFees).toInt256().wadMul(insuranceFee);

        // open position
        vm.startPrank(alice);
        clearingHouse.extendPositionWithCollateral(0, alice, depositAmount, ua, positionAmount, direction, 0);
        LibPerpetual.TraderPosition memory traderPosition = viewer.getTraderPosition(0, alice);

        // calculate expected profit
        uint256 proposedAmount = viewer.getTraderProposedAmount(0, alice, 1e18, 100, 0);
        int256 eProfit = _getExpectedTraderProfit(
            traderPosition, proposedAmount, long ? VBASE_INDEX : VQUOTE_INDEX, long ? VQUOTE_INDEX : VBASE_INDEX, long
        );

        // calculate expected funding payment
        int256 eFunding = _getExpectedFundingPayment(traderPosition, block.timestamp + durationPassed, long);

        // close position
        vm.warp(block.timestamp + durationPassed);
        clearingHouse.changePosition(0, proposedAmount, 0, _getCloseTradeDirection(traderPosition));

        // check trader profit
        clearingHouse.withdraw(viewer.getBalance(alice, 0).toUint256(), ua);
        assertEq(
            ua.balanceOf(alice).toInt256(),
            balanceBefore.toInt256() + eProfit + eFunding - tradingFees - insuranceFees,
            "balance mismatch after closing position"
        );
    }

    function testFuzz_OpenPositionWithMarginFromDifferentCollaterals(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount, maxTradeAmount);
        _dealAndProvideLiquidity(bob, depositAmount * 20);
        _dealAndApprove(alice, depositAmount);
        _dealUSDCAndApprove(bob, depositAmount);
        _dealUSDCAndApprove(alice, depositAmount);

        uint256 usdcDepositAmount = LibReserve.wadToToken(usdc.decimals(), depositAmount);

        // open a position using USDC as collateral
        vm.startPrank(alice);
        uint256 percentageFee = curveCryptoViews.get_dy_fees_perc(cryptoSwap, VQUOTE_INDEX, VBASE_INDEX, depositAmount);
        vm.expectEmit(true, false, false, false); // do not check event data
        emit Deposit(alice, address(usdc), usdcDepositAmount);
        emit ChangePosition(
            0,
            alice,
            LibPerpetual.Side.Long,
            depositAmount.toInt256(),
            depositAmount.wadMul(percentageFee).toInt256(),
            0,
            0,
            0,
            false,
            false
        );
        clearingHouse.extendPositionWithCollateral(
            0, alice, usdcDepositAmount, usdc, depositAmount, LibPerpetual.Side.Long, 0
        );

        // trader openNotional in 18 decimals as usual (virtual tokens)
        uint256 absAliceOpenNotional = int256(perpetual.getTraderPosition(alice).openNotional).abs().toUint256();
        assertEq(absAliceOpenNotional, depositAmount, "openNotional mismatch after opening position");

        // trader collateral in USD harmonized to 18 decimals
        uint256 usdcDepositWadAmount = LibReserve.tokenToWad(usdc.decimals(), usdcDepositAmount);
        uint256 aliceReserveValue = viewer.getReserveValue(alice, false).toUint256();

        // get expected fees
        uint256 eInsuranceFee = absAliceOpenNotional.wadMul(insuranceFee.toUint256());
        uint256 eTradingFee = absAliceOpenNotional.wadMul(percentageFee);

        // check new vault balance
        // note: fundingRate is null in this case
        uint256 eNewVaultBalance = usdcDepositWadAmount - eInsuranceFee - eTradingFee;
        assertApproxEqRel(
            aliceReserveValue,
            eNewVaultBalance,
            1e16, // 1% error due to minor variations in oracle price for USDC
            "vault balance mismatch after opening position"
        );
    }

    function testFuzz_AddAllCollateralsWhenOpeningPosition(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount * 10, maxTradeAmount / 2);
        _dealAndProvideLiquidity(bob, depositAmount * 20);
        _dealAndProvideLiquidity(lp, depositAmount * 20);
        _dealAndApprove(alice, depositAmount * 2);
        _dealUSDCAndApprove(alice, depositAmount * 2);
        _dealUSDCAndApprove(bob, depositAmount * 2);

        vm.startPrank(alice);

        uint256 riskWeight = perpetual.riskWeight();
        uint256 depositAmountHalfUnderMargin = (depositAmount / 10).wadMul(riskWeight);

        // provide some collateral in UA
        clearingHouse.deposit(depositAmountHalfUnderMargin, ua);
        uint256 aliceReserveValueAfterFirstDeposit = viewer.getReserveValue(alice, false).toUint256();

        // opening position should fail due to insufficient margin
        vm.expectRevert(IClearingHouse.ClearingHouse_ExtendPositionInsufficientMargin.selector);
        clearingHouse.changePosition(0, depositAmount * 2, 0, LibPerpetual.Side.Long);

        // double the collateral amount using USDC
        uint256 usdcDepositAmount = LibReserve.wadToToken(usdc.decimals(), depositAmountHalfUnderMargin);
        clearingHouse.deposit(usdcDepositAmount, usdc);
        uint256 aliceReserveValueAfterSecondDeposit = viewer.getReserveValue(alice, false).toUint256();
        assertApproxEqRel(
            aliceReserveValueAfterSecondDeposit,
            aliceReserveValueAfterFirstDeposit * 2,
            1e16, // 1% error due to minor variations in oracle price for USDC
            "reserve value mismatch after second deposit"
        );

        // opening position should succeed now that margin is sufficient
        vm.expectEmit(false, false, false, false); // do not check event data
        emit ChangePosition(0, alice, LibPerpetual.Side.Long, 0, 0, 0, 0, 0, false, false);
        clearingHouse.changePosition(0, depositAmount * 2, 0, LibPerpetual.Side.Long);
    }

    function testFuzz_FailsToCreateShortPositionExceedingAvailableLiquidity(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount, maxTradeAmount / 2);
        _dealAndProvideLiquidity(bob, depositAmount * 20);

        vm.startPrank(alice);

        uint256 maxShortPositionSize = perpetual.getGlobalPosition().totalBaseProvided;
        uint256 smallTrade = 1 ether;
        perpetual.__TestPerpetual__setTraderPosition(
            alice, 1, (maxShortPositionSize - smallTrade).toInt256().toInt128() * -1, 0
        );

        vm.expectRevert(IPerpetual.Perpetual_TooMuchExposure.selector);
        clearingHouse.changePosition(0, smallTrade + 1, 0, LibPerpetual.Side.Short);

        // will be reverted anyways (margin is not enough)
        LibPerpetual.TraderPosition memory alicePosition = perpetual.getTraderPosition(alice);
        uint256 maxPosition = perpetual.maxPosition();
        if (
            int256(alicePosition.openNotional).abs().toUint256() > maxPosition
                || int256(alicePosition.positionSize).abs().wadMul(perpetual.indexPrice()).toUint256() > maxPosition
        ) {
            vm.expectRevert(IPerpetual.Perpetual_MaxPositionSize.selector);
        } else {
            vm.expectRevert(IClearingHouse.ClearingHouse_ExtendPositionInsufficientMargin.selector);
        }
        clearingHouse.changePosition(0, smallTrade, 0, LibPerpetual.Side.Short);
    }
}
