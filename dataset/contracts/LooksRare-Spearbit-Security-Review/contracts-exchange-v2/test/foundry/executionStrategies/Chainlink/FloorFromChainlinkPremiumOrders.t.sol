// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries and interfaces
import {OrderStructs} from "../../../../contracts/libraries/OrderStructs.sol";
import {WrongCurrency} from "../../../../contracts/interfaces/SharedErrors.sol";

// Shared errors
import {BidTooLow, OrderInvalid} from "../../../../contracts/interfaces/SharedErrors.sol";

// Strategies
import {BaseStrategyChainlinkMultiplePriceFeeds} from "../../../../contracts/executionStrategies/Chainlink/BaseStrategyChainlinkMultiplePriceFeeds.sol";
import {BaseStrategyChainlinkPriceLatency} from "../../../../contracts/executionStrategies/Chainlink/BaseStrategyChainlinkPriceLatency.sol";
import {StrategyFloorFromChainlink} from "../../../../contracts/executionStrategies/Chainlink/StrategyFloorFromChainlink.sol";

// Mock files and other tests
import {MockChainlinkAggregator} from "../../../mock/MockChainlinkAggregator.sol";
import {FloorFromChainlinkOrdersTest} from "./FloorFromChainlinkOrders.t.sol";

abstract contract FloorFromChainlinkPremiumOrdersTest is FloorFromChainlinkOrdersTest {
    uint256 internal premium;

    function testFloorFromChainlinkPremiumPriceFeedNotAvailable() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyFloorFromChainlink.updateMaxLatency(MAXIMUM_LATENCY);

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, BaseStrategyChainlinkMultiplePriceFeeds.PriceFeedNotAvailable.selector);

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumOraclePriceNotRecentEnough() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, BaseStrategyChainlinkPriceLatency.PriceNotRecentEnough.selector);

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumChainlinkPriceLessThanOrEqualToZero() public {
        MockChainlinkAggregator aggregator = new MockChainlinkAggregator();

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorFromChainlink.updateMaxLatency(MAXIMUM_LATENCY);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), address(aggregator));
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, BaseStrategyChainlinkPriceLatency.InvalidChainlinkPrice.selector);

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);

        aggregator.setAnswer(-1);
        vm.expectRevert(BaseStrategyChainlinkPriceLatency.InvalidChainlinkPrice.selector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumMakerAskItemIdsLengthNotOne() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        makerAsk.itemIds = new uint256[](0);

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumMakerAskAmountsLengthNotOne() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        makerAsk.amounts = new uint256[](0);

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumMakerAskAmountNotOne() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        makerAsk.amounts = amounts;

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumTakerBidAmountNotOne() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        takerBid.amounts = amounts;

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerAskValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        vm.expectRevert(OrderInvalid.selector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumMakerAskTakerBidItemIdsMismatch() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 2;
        takerBid.itemIds = itemIds;

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerAskValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        vm.expectRevert(OrderInvalid.selector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumBidTooLow() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        takerBid.maxPrice = makerAsk.minPrice - 1 wei;

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerAskValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        vm.expectRevert(BidTooLow.selector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumWrongCurrency() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        vm.prank(_owner);
        looksRareProtocol.updateCurrencyWhitelistStatus(address(looksRareToken), true);
        makerAsk.currency = address(looksRareToken);

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, WrongCurrency.selector);

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function _executeTakerBid(
        OrderStructs.TakerBid memory takerBid,
        OrderStructs.MakerAsk memory makerAsk,
        bytes memory signature
    ) internal {
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function _setPremium(uint256 _premium) internal {
        premium = _premium;
    }
}
