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
import "../../lib/chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// libraries
import "../../contracts/lib/LibMath.sol";
import "../../contracts/lib/LibPerpetual.sol";

contract TwapTest is Deployment {
    event TwapUpdated(int256 newOracleTwap, int256 newMarketTwap);
    event FundingRateUpdated(int256 cumulativeFundingRate, int256 cumulativeFundingPerLpToken, int256 fundingRate);

    using LibMath for int256;
    using LibMath for uint256;

    address traderOne = address(789);

    int256 initialPrice;
    uint256 initialTwapPeriod;

    function setUp() public virtual override {
        vm.deal(traderOne, 100 ether);
        super.setUp();

        initialPrice = perpetual.oracleTwap();
        initialTwapPeriod = perpetual.twapFrequency();
    }

    function _recordChainlinkPrice(int256 price, uint256 timeElapsed) internal {
        vm.mockCall(
            address(baseOracle),
            abi.encodeWithSelector(baseOracle.latestRoundData.selector),
            abi.encode(0, price, block.timestamp, block.timestamp, 0)
        );
        vm.warp(block.timestamp + timeElapsed);
        perpetual.updateGlobalState();
    }

    function _recordCurvePrice(uint256 price, uint256 timeElapsed) internal {
        vm.mockCall(address(cryptoSwap), abi.encodeWithSelector(cryptoSwap.last_prices.selector), abi.encode(price));
        vm.warp(block.timestamp + timeElapsed);
        perpetual.updateGlobalState();
    }

    function testFuzz_ShouldAccountForVariationsInUnderlyingIndexPrice(
        int256 firstPrice,
        int256 secondPrice,
        int256 thirdPrice,
        int256 fourthPrice
    ) public {
        vm.assume(firstPrice > 0 && secondPrice > 0 && thirdPrice > 0 && fourthPrice > 0);
        vm.assume(
            firstPrice < type(int64).max && secondPrice < type(int64).max && thirdPrice < type(int64).max
                && fourthPrice < type(int64).max
        );

        // skip first period
        vm.warp(block.timestamp + initialTwapPeriod * 2);
        uint256 initialTimestamp = block.timestamp;
        perpetual.updateGlobalState();

        uint256 testInterval = initialTwapPeriod / 4;

        assertEq(perpetual.getGlobalPosition().timeOfLastTrade, initialTimestamp);
        assertEq(perpetual.getGlobalPosition().timeOfLastTwapUpdate, initialTimestamp);
        assertEq(perpetual.oracleTwap(), initialPrice);

        int256 oracleCumulativeAmountAtStart = perpetual.oracleCumulativeAmount();
        assertEq(perpetual.oracleCumulativeAmountAtBeginningOfPeriod(), oracleCumulativeAmountAtStart);

        // update the oracle & global state
        _recordChainlinkPrice(firstPrice, testInterval);

        uint256 firstTimestamp = block.timestamp;
        int256 firstPriceResult = perpetual.indexPrice();

        int256 productPriceTime = firstPriceResult * testInterval.toInt256();
        int256 expectedCumulativeAmountFirstUpdate = oracleCumulativeAmountAtStart + productPriceTime;

        assertEq(perpetual.getGlobalPosition().timeOfLastTrade, firstTimestamp);
        assertEq(perpetual.getGlobalPosition().timeOfLastTwapUpdate, initialTimestamp);
        assertEq(perpetual.oracleTwap(), initialPrice);
        assertEq(perpetual.oracleCumulativeAmount(), expectedCumulativeAmountFirstUpdate);
        assertEq(perpetual.oracleCumulativeAmountAtBeginningOfPeriod(), oracleCumulativeAmountAtStart);

        int256 weightedPrice = firstPriceResult * testInterval.toInt256();

        int256[3] memory prices = [secondPrice, thirdPrice, fourthPrice];

        // loop through the updates
        for (uint8 i = 0; i < 3; i++) {
            // pass some time and update the oracle
            _recordChainlinkPrice(prices[i], testInterval);

            // update the weighted price
            weightedPrice += perpetual.indexPrice() * testInterval.toInt256();
        }

        int256 expectedTwap = weightedPrice / initialTwapPeriod.toInt256();

        assertEq(perpetual.getGlobalPosition().timeOfLastTrade, block.timestamp);
        assertEq(perpetual.getGlobalPosition().timeOfLastTwapUpdate, block.timestamp);
        assertEq(perpetual.oracleTwap(), expectedTwap);
        assertEq(perpetual.oracleCumulativeAmountAtBeginningOfPeriod(), oracleCumulativeAmountAtStart + weightedPrice);
        assertEq(perpetual.oracleCumulativeAmount(), oracleCumulativeAmountAtStart + weightedPrice);
    }

    function testFuzz_ShouldAccountForVariationsInUnderlyingCurvePrice(
        uint256 firstPrice,
        uint256 secondPrice,
        uint256 thirdPrice,
        uint256 fourthPrice
    ) public {
        vm.assume(
            firstPrice < type(uint64).max && secondPrice < type(uint64).max && thirdPrice < type(uint64).max
                && fourthPrice < type(uint64).max
        );

        _recordCurvePrice(initialPrice.toUint256(), 0);
        _recordChainlinkPrice(initialPrice, 0);
        // skip first period
        vm.warp(block.timestamp + initialTwapPeriod * 2);
        uint256 initialTimestamp = block.timestamp;
        perpetual.updateGlobalState();
        emit log("TSET");

        uint256 testInterval = initialTwapPeriod / 4;

        assertEq(perpetual.getGlobalPosition().timeOfLastTrade, initialTimestamp);
        assertEq(perpetual.getGlobalPosition().timeOfLastTwapUpdate, initialTimestamp);
        assertEq(perpetual.marketTwap(), initialPrice);

        int256 marketCumulativeAmountAtStart = perpetual.marketCumulativeAmount();
        assertEq(perpetual.marketCumulativeAmountAtBeginningOfPeriod(), marketCumulativeAmountAtStart);

        // update the market price & global state
        _recordCurvePrice(firstPrice, testInterval);

        uint256 firstTimestamp = block.timestamp;
        int256 firstPriceResult = perpetual.marketPrice().toInt256();

        int256 productPriceTime = firstPriceResult * testInterval.toInt256();
        int256 expectedCumulativeAmountFirstUpdate = marketCumulativeAmountAtStart + productPriceTime;

        assertEq(perpetual.getGlobalPosition().timeOfLastTrade, firstTimestamp);
        assertEq(perpetual.getGlobalPosition().timeOfLastTwapUpdate, initialTimestamp);
        assertEq(perpetual.marketTwap(), initialPrice);
        assertEq(perpetual.marketCumulativeAmount(), expectedCumulativeAmountFirstUpdate);
        assertEq(perpetual.marketCumulativeAmountAtBeginningOfPeriod(), marketCumulativeAmountAtStart);

        int256 weightedPrice = firstPriceResult * testInterval.toInt256();

        uint256[3] memory prices = [secondPrice, thirdPrice, fourthPrice];

        // loop through the updates
        for (uint8 i = 0; i < 3; i++) {
            // pass some time and update the oracle
            _recordCurvePrice(prices[i], testInterval);

            // update the weighted price
            weightedPrice += perpetual.marketPrice().toInt256() * testInterval.toInt256();
        }

        int256 expectedTwap = weightedPrice / initialTwapPeriod.toInt256();

        assertEq(perpetual.getGlobalPosition().timeOfLastTrade, block.timestamp);
        assertEq(perpetual.getGlobalPosition().timeOfLastTwapUpdate, block.timestamp);
        assertEq(perpetual.marketTwap(), expectedTwap);
        assertEq(perpetual.marketCumulativeAmountAtBeginningOfPeriod(), marketCumulativeAmountAtStart + weightedPrice);
        assertEq(perpetual.marketCumulativeAmount(), marketCumulativeAmountAtStart + weightedPrice);
    }

    function test_ShouldFailToUpdateGlobalStateWhenPaused() public {
        perpetual.pause();
        vm.expectRevert("Pausable: paused");
        perpetual.updateGlobalState();

        // clearingHouse should still be able to update global state
        clearingHouse.updateGlobalState();
    }

    function test_ShouldUpdateGlobalState() public {
        vm.warp(block.timestamp + 1);
        vm.expectEmit(true, true, false, false);
        emit FundingRateUpdated(0, 0, 0);
        perpetual.updateGlobalState();

        vm.warp(block.timestamp + initialTwapPeriod * 2);

        vm.expectEmit(true, true, false, false);
        emit TwapUpdated(0, 0);
        vm.expectEmit(true, true, false, false);
        emit FundingRateUpdated(0, 0, 0);
        perpetual.updateGlobalState();
    }
}
