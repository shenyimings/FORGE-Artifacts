// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

// contracts
import {Deployment} from "../helpers/Deployment.MainnetFork.sol";

// interfaces
import "../../contracts/interfaces/ICryptoSwap.sol";
import "../../contracts/interfaces/ICurveCryptoFactory.sol";
import "../../contracts/interfaces/IVault.sol";
import "../../contracts/interfaces/IVBase.sol";
import "../../contracts/interfaces/IVQuote.sol";
import "../../contracts/interfaces/IInsurance.sol";
import "../../contracts/interfaces/IPerpetual.sol";
import "../../lib/chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// libraries
import "../../contracts/lib/LibMath.sol";
import "../../contracts/lib/LibPerpetual.sol";

contract FundingRateTest is Deployment {
    event FundingRateUpdated(int256 addedFundingRate, int256 removedFundingRate, int256 cumFundingRate);
    event FundingPaid(
        address indexed account,
        int256 amount,
        int256 globalCumulativeFundingRate,
        int256 userCumulativeFundingRate,
        bool isTrader
    );

    using LibMath for int256;
    using LibMath for uint256;
    using LibMath for int128;
    using LibMath for uint128;

    address liquidityProviderOne = address(123);
    address liquidityProviderTwo = address(456);
    address traderOne = address(789);

    uint24 uaHeartBeat;

    function setUp() public virtual override {
        deal(liquidityProviderOne, 100 ether);
        deal(liquidityProviderTwo, 100 ether);
        deal(traderOne, 100 ether);

        super.setUp();
        (uaHeartBeat,,,) = oracle.assetToOracles(address(ua));
    }

    // INTERNAL FUNCTIONS

    function calcCurrentTradePremium(uint256 marketPrice, uint256 indexPrice) internal pure returns (int256) {
        return marketPrice.toInt256() - indexPrice.toInt256();
    }

    function calcFundingRate(int256 sensitivity, int256 weightedTradePremiumOverLastPeriod, int256 timePassed)
        internal
        pure
        returns (int256)
    {
        return (sensitivity.wadMul(weightedTradePremiumOverLastPeriod) * timePassed) / 1 days;
    }

    // TESTS

    function test_ExpectedInitialState() public {
        LibPerpetual.GlobalPosition memory globalPosition = perpetual.getGlobalPosition();
        assertEq(globalPosition.cumFundingRate, 0);
    }

    function testFuzz_UpdateFundingRateCorrectlyInSubsequentCalls(
        uint256 marketPrice,
        uint256 indexPrice,
        uint32 firstDuration,
        uint32 secondDuration
    ) public {
        vm.assume(marketPrice < type(uint64).max);
        vm.assume(indexPrice < type(uint64).max);

        int256 sensitivity = perpetual.sensitivity();

        perpetual.__TestPerpetual__setTWAP(marketPrice.toInt256().toInt128(), indexPrice.toInt256().toInt128());

        uint256 startTime = perpetual.getGlobalPosition().timeOfLastTrade;

        /**
         * FIRST TRADE **************
         */
        // initial parameters for the first call

        vm.warp(block.timestamp + firstDuration);
        perpetual.__TestPerpetual__updateFunding();

        int256 estimatedCurrentTraderPremiumFirstTrade = calcCurrentTradePremium(marketPrice, indexPrice);
        uint256 timeOfFirstTrade = block.timestamp;
        uint256 estimatedTimePassedFirstTrade = timeOfFirstTrade - startTime;
        int256 estimatedFundingRateFirstTrade = calcFundingRate(
            sensitivity, estimatedCurrentTraderPremiumFirstTrade, estimatedTimePassedFirstTrade.toInt256()
        );

        assertEq(estimatedFundingRateFirstTrade, perpetual.getGlobalPosition().cumFundingRate);

        /**
         * SECOND TRADE **************
         */
        // initial parameters for the second call
        vm.warp(block.timestamp + secondDuration);

        int256 estimatedCurrentTraderPremiumSecondTrade = calcCurrentTradePremium(marketPrice, indexPrice);
        uint256 timeOfSecondTrade = block.timestamp;
        uint256 estimatedTimePassedSecondTrade = timeOfSecondTrade - timeOfFirstTrade;
        int256 estimatedAddedFundingRateSecondTrade = calcFundingRate(
            sensitivity, estimatedCurrentTraderPremiumSecondTrade, estimatedTimePassedSecondTrade.toInt256()
        );
        int256 estimatedFundingRateSecondTrade = estimatedFundingRateFirstTrade + estimatedAddedFundingRateSecondTrade;

        // expect emit FundingRateUpdated event
        vm.expectEmit(true, true, true, false);
        emit FundingRateUpdated(estimatedAddedFundingRateSecondTrade, int256(0), estimatedFundingRateSecondTrade);
        perpetual.__TestPerpetual__updateFunding();

        LibPerpetual.GlobalPosition memory globalPosition = perpetual.getGlobalPosition();

        assertEq(globalPosition.timeOfLastTrade, timeOfSecondTrade);
        assertEq(globalPosition.cumFundingRate, estimatedFundingRateSecondTrade);
    }

    function testFuzz_GetFundingPaymentsFromGlobalForTrader(
        int128 initialCumFundingRate,
        int128 openNotional,
        int128 positionSize,
        uint32 duration,
        int128 secondCumFundingRate
    ) public {
        vm.assume((openNotional > 0) != (positionSize > 0));
        vm.assume(initialCumFundingRate.abs().toUint256() < type(uint64).max);
        vm.assume(openNotional.abs().toUint256() < type(uint64).max);
        vm.assume(positionSize.abs().toUint256() < type(uint64).max);
        vm.assume(secondCumFundingRate.abs().toUint256() < type(uint64).max);

        uint256 startTime = block.timestamp;

        perpetual.__TestPerpetual__setGlobalPositionFundingRate(startTime.toUint64(), initialCumFundingRate);

        perpetual.__TestPerpetual__setTraderPosition(traderOne, openNotional, positionSize, initialCumFundingRate);

        int256 estimatedFirstFundingPayment = 0;

        // expect emit FundingPaid event
        vm.expectEmit(true, true, true, false);
        emit FundingPaid(traderOne, estimatedFirstFundingPayment, initialCumFundingRate, initialCumFundingRate, true);
        perpetual.__TestPerpetual__settleTraderNoUpdate(traderOne);

        assertEq(
            viewer.__TestClearingHouseViewer__getTraderFundingPaymentsAtTimestamp(0, traderOne, startTime),
            estimatedFirstFundingPayment
        );

        // pass some time
        vm.warp(block.timestamp + duration);

        uint256 secondTime = block.timestamp;
        perpetual.__TestPerpetual__setGlobalPositionFundingRate(secondTime.toUint64(), secondCumFundingRate);

        LibPerpetual.TraderPosition memory traderPositionBeforeSecondUpdate = perpetual.getTraderPosition(traderOne);
        LibPerpetual.GlobalPosition memory globalPositionBeforeSecondUpdate = perpetual.getGlobalPosition();

        int256 estimatedSecondFundingRate =
            traderPositionBeforeSecondUpdate.cumFundingRate - globalPositionBeforeSecondUpdate.cumFundingRate;
        int256 estimatedSecondFundingPayment =
            estimatedSecondFundingRate.wadMul(traderPositionBeforeSecondUpdate.positionSize);

        int256 secondFundingPayment =
            viewer.__TestClearingHouseViewer__getTraderFundingPaymentsAtTimestamp(0, traderOne, secondTime);
        assertEq(secondFundingPayment, estimatedSecondFundingPayment);

        // expect emit FundingPaid event
        vm.expectEmit(true, true, true, false);
        emit FundingPaid(
            traderOne,
            estimatedSecondFundingPayment,
            secondCumFundingRate,
            traderPositionBeforeSecondUpdate.cumFundingRate,
            true
        );
        perpetual.__TestPerpetual__settleTraderNoUpdate(traderOne);

        // assert trader position cumFundingRate is updated and equal to global cumFundingRate
        assertEq(perpetual.getTraderPosition(traderOne).cumFundingRate, perpetual.getGlobalPosition().cumFundingRate);
        // assert trader position fundingPayment is updated
        assertEq(viewer.__TestClearingHouseViewer__getTraderFundingPaymentsAtTimestamp(0, traderOne, secondTime), 0);
    }

    function testFuzz_GetFundingPaymentsFromGlobalForLp(
        int128 initialCumFundingPerLpToken,
        uint128 positionSize,
        uint32 duration,
        int128 secondCumFundingPerLpToken
    ) public {
        vm.assume(positionSize > 0);
        vm.assume(duration < uaHeartBeat);
        vm.assume(initialCumFundingPerLpToken.abs().toUint256() < type(uint64).max);
        vm.assume(positionSize < type(uint64).max);
        vm.assume(secondCumFundingPerLpToken.abs().toUint256() < type(uint64).max);

        uint256 startTime = block.timestamp;

        perpetual.__TestPerpetual__setGlobalPositionCumFundingPerLpToken(
            startTime.toUint64(), initialCumFundingPerLpToken
        );

        perpetual.__TestPerpetual__setLpPosition(
            traderOne, 0, 1 ether, 1 ether, 0, 0, 0, 0, initialCumFundingPerLpToken
        );

        int256 estimatedFirstFundingPayment = 0;

        // expect emit FundingPaid event
        vm.expectEmit(true, true, false, false);
        emit FundingPaid(
            traderOne, estimatedFirstFundingPayment, initialCumFundingPerLpToken, initialCumFundingPerLpToken, false
        );
        perpetual.__TestPerpetual__settleLpNoUpdate(traderOne);

        assertEq(
            viewer.__TestClearingHouseViewer__getLpFundingPaymentsAtTimestamp(0, traderOne, startTime),
            estimatedFirstFundingPayment
        );

        // set new global position
        // pass some time
        vm.warp(block.timestamp + duration);
        uint256 secondTime = block.timestamp;

        perpetual.__TestPerpetual__setGlobalPositionCumFundingPerLpToken(
            secondTime.toUint64(), secondCumFundingPerLpToken
        );

        LibPerpetual.LiquidityProviderPosition memory lpPositionBeforeSecondUpdate = perpetual.getLpPosition(traderOne);
        LibPerpetual.GlobalPosition memory globalPositionBeforeSecondUpdate = perpetual.getGlobalPosition();

        int256 estimatedSecondFundingRate =
            globalPositionBeforeSecondUpdate.cumFundingPerLpToken - lpPositionBeforeSecondUpdate.cumFundingPerLpToken;
        int256 estimatedSecondFundingPayment =
            estimatedSecondFundingRate.wadMul(uint256(lpPositionBeforeSecondUpdate.liquidityBalance).toInt256());

        int256 secondFundingPayment =
            viewer.__TestClearingHouseViewer__getLpFundingPaymentsAtTimestamp(0, traderOne, secondTime);

        assertEq(secondFundingPayment, estimatedSecondFundingPayment);

        // expect emit FundingPaid event
        vm.expectEmit(true, true, true, false);
        emit FundingPaid(
            traderOne, estimatedSecondFundingPayment, secondCumFundingPerLpToken, initialCumFundingPerLpToken, false
        );
        perpetual.__TestPerpetual__settleLpNoUpdate(traderOne);

        // assert lp position cumFundingRate is updated and equal to global cumFundingRate
        assertEq(
            perpetual.getLpPosition(traderOne).cumFundingPerLpToken, perpetual.getGlobalPosition().cumFundingPerLpToken
        );
        // assert lp position fundingPayment is updated
        assertEq(viewer.__TestClearingHouseViewer__getLpFundingPaymentsAtTimestamp(0, traderOne, secondTime), 0);
    }
}
