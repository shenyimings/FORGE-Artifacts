// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries and interfaces
import {OrderStructs} from "../../../../contracts/libraries/OrderStructs.sol";
import {StrategyChainlinkFloor} from "../../../../contracts/executionStrategies/Chainlink/StrategyChainlinkFloor.sol";

// Errors and constants
import {AmountInvalid, AskTooHigh, CurrencyInvalid, OrderInvalid} from "../../../../contracts/errors/SharedErrors.sol";
import {ChainlinkPriceInvalid, PriceFeedNotAvailable, PriceNotRecentEnough} from "../../../../contracts/errors/ChainlinkErrors.sol";
import {MAKER_ORDER_TEMPORARILY_INVALID_NON_STANDARD_SALE, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE} from "../../../../contracts/constants/ValidationCodeConstants.sol";

// Mocks and other tests
import {MockChainlinkAggregator} from "../../../mock/MockChainlinkAggregator.sol";
import {FloorFromChainlinkOrdersTest} from "./FloorFromChainlinkOrders.t.sol";

abstract contract FloorFromChainlinkDiscountOrdersTest is FloorFromChainlinkOrdersTest {
    uint256 internal discount;

    function setUp() public virtual override {
        super.setUp();
    }

    function testFloorFromChainlinkDiscountPriceFeedNotAvailable() public {
        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        bytes4 errorSelector = PriceFeedNotAvailable.selector;

        _assertOrderIsInvalid(makerBid, errorSelector);
        _assertMakerOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_TEMPORARILY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountOraclePriceNotRecentEnough() public {
        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        makerBid.startTime = CHAINLINK_PRICE_UPDATED_AT;
        uint256 latencyViolationTimestamp = CHAINLINK_PRICE_UPDATED_AT + MAXIMUM_LATENCY + 1 seconds;
        makerBid.endTime = latencyViolationTimestamp;

        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        bytes4 errorSelector = PriceNotRecentEnough.selector;

        vm.prank(_owner);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);

        vm.warp(latencyViolationTimestamp);

        _assertOrderIsInvalid(makerBid, errorSelector);
        _assertMakerOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_TEMPORARILY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountChainlinkPriceLessThanOrEqualToZero() public {
        MockChainlinkAggregator aggregator = new MockChainlinkAggregator();

        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        vm.prank(_owner);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), address(aggregator));

        bytes4 errorSelector = ChainlinkPriceInvalid.selector;

        _assertOrderIsInvalid(makerBid, errorSelector);
        _assertMakerOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_TEMPORARILY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);

        aggregator.setAnswer(-1);

        _assertOrderIsInvalid(makerBid, errorSelector);
        _assertMakerOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_TEMPORARILY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountMakerBidAmountsLengthNotOne() public {
        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        makerBid.amounts = new uint256[](0);

        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = OrderInvalid.selector;

        _assertOrderIsInvalid(makerBid, errorSelector);
        _assertMakerOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountMakerBidAmountNotOne() public {
        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        uint256[] memory amounts = new uint256[](1);
        // Bidder will probably try a higher number
        amounts[0] = 2;
        makerBid.amounts = amounts;

        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = OrderInvalid.selector;

        _assertOrderIsInvalid(makerBid, errorSelector);
        _assertMakerOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(AmountInvalid.selector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountAskTooHigh() public {
        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });
        (, uint256 minPrice) = abi.decode(takerAsk.additionalParameters, (uint256, uint256));
        makerBid.price = minPrice - 1 wei;

        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        _assertOrderIsValid(makerBid);
        _assertValidMakerOrder(makerBid, signature);

        vm.expectRevert(AskTooHigh.selector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountCurrencyInvalid() public {
        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        vm.prank(_owner);
        looksRareProtocol.updateCurrencyStatus(address(looksRareToken), true);
        makerBid.currency = address(looksRareToken);

        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = CurrencyInvalid.selector;

        _assertOrderIsInvalid(makerBid, errorSelector);
        _assertMakerOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_TEMPORARILY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function _setDiscount(uint256 _discount) internal {
        discount = _discount;
    }

    function _executeTakerAsk(
        OrderStructs.Taker memory takerAsk,
        OrderStructs.Maker memory makerBid,
        bytes memory signature
    ) internal {
        vm.prank(takerUser);
        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function _assertOrderIsValid(OrderStructs.Maker memory makerBid) internal {
        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerOrderValid(makerBid, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);
    }

    function _assertOrderIsInvalid(
        OrderStructs.Maker memory makerBid,
        bytes4 expectedErrorSelector
    ) private returns (bytes4) {
        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerOrderValid(makerBid, selector);
        assertFalse(isValid);
        assertEq(errorSelector, expectedErrorSelector);
        return errorSelector;
    }
}
