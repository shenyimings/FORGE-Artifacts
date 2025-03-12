// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries and interfaces
import {OrderStructs} from "../../../../contracts/libraries/OrderStructs.sol";
import {BaseStrategyChainlinkPriceLatency} from "../../../../contracts/executionStrategies/Chainlink/BaseStrategyChainlinkPriceLatency.sol";
import {BaseStrategyChainlinkMultiplePriceFeeds} from "../../../../contracts/executionStrategies/Chainlink/BaseStrategyChainlinkMultiplePriceFeeds.sol";
import {StrategyFloorFromChainlink} from "../../../../contracts/executionStrategies/Chainlink/StrategyFloorFromChainlink.sol";

// Shared errors
import {AskTooHigh, OrderInvalid, WrongCurrency} from "../../../../contracts/interfaces/SharedErrors.sol";

// Mocks and other tests
import {MockChainlinkAggregator} from "../../../mock/MockChainlinkAggregator.sol";
import {FloorFromChainlinkOrdersTest} from "./FloorFromChainlinkOrders.t.sol";

abstract contract FloorFromChainlinkDiscountOrdersTest is FloorFromChainlinkOrdersTest {
    uint256 internal discount;

    function testFloorFromChainlinkDiscountPriceFeedNotAvailable() public {
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        vm.prank(_owner);
        strategyFloorFromChainlink.updateMaxLatency(MAXIMUM_LATENCY);

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerBidValid(makerBid, selector);
        assertFalse(isValid);
        assertEq(errorSelector, BaseStrategyChainlinkMultiplePriceFeeds.PriceFeedNotAvailable.selector);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountOraclePriceNotRecentEnough() public {
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        vm.prank(_owner);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerBidValid(makerBid, selector);
        assertFalse(isValid);
        assertEq(errorSelector, BaseStrategyChainlinkPriceLatency.PriceNotRecentEnough.selector);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountChainlinkPriceLessThanOrEqualToZero() public {
        MockChainlinkAggregator aggregator = new MockChainlinkAggregator();

        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorFromChainlink.updateMaxLatency(MAXIMUM_LATENCY);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), address(aggregator));
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerBidValid(makerBid, selector);
        assertFalse(isValid);
        assertEq(errorSelector, BaseStrategyChainlinkPriceLatency.InvalidChainlinkPrice.selector);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);

        aggregator.setAnswer(-1);

        (isValid, errorSelector) = strategyFloorFromChainlink.isMakerBidValid(makerBid, selector);
        assertFalse(isValid);
        assertEq(errorSelector, BaseStrategyChainlinkPriceLatency.InvalidChainlinkPrice.selector);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountTakerAskItemIdsLengthNotOne() public {
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        takerAsk.itemIds = new uint256[](0);

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerBidValid(makerBid, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        vm.expectRevert(OrderInvalid.selector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountTakerAskAmountsLengthNotOne() public {
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        takerAsk.amounts = new uint256[](0);

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerBidValid(makerBid, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        vm.expectRevert(OrderInvalid.selector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountMakerBidAmountsLengthNotOne() public {
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        makerBid.amounts = new uint256[](0);

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerBidValid(makerBid, selector);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountTakerAskZeroAmount() public {
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        uint256[] memory amounts = new uint256[](1);
        // Seller will probably try 0
        amounts[0] = 0;
        takerAsk.amounts = amounts;

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerBidValid(makerBid, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        vm.expectRevert(OrderInvalid.selector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountMakerBidAmountNotOne() public {
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        uint256[] memory amounts = new uint256[](1);
        // Bidder will probably try a higher number
        amounts[0] = 2;
        makerBid.amounts = amounts;

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerBidValid(makerBid, selector);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountAskTooHigh() public {
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });
        makerBid.maxPrice = takerAsk.minPrice - 1 wei;

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerBidValid(makerBid, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        vm.expectRevert(AskTooHigh.selector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountWrongCurrency() public {
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        vm.prank(_owner);
        looksRareProtocol.updateCurrencyWhitelistStatus(address(looksRareToken), true);
        makerBid.currency = address(looksRareToken);

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerBidValid(makerBid, selector);
        assertFalse(isValid);
        assertEq(errorSelector, WrongCurrency.selector);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function _setDiscount(uint256 _discount) internal {
        discount = _discount;
    }

    function _executeTakerAsk(
        OrderStructs.TakerAsk memory takerAsk,
        OrderStructs.MakerBid memory makerBid,
        bytes memory signature
    ) internal {
        vm.prank(takerUser);
        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }
}
