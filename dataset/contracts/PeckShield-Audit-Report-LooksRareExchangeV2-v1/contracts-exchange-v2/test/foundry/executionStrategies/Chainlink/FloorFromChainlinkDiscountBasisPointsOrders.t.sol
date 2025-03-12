// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// LooksRare libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Libraries and interfaces
import {OrderStructs} from "../../../../contracts/libraries/OrderStructs.sol";
import {IExecutionManager} from "../../../../contracts/interfaces/IExecutionManager.sol";

// Errors and constants
import {OrderInvalid} from "../../../../contracts/errors/SharedErrors.sol";
import {ONE_HUNDRED_PERCENT_IN_BP} from "../../../../contracts/constants/NumericConstants.sol";
import {MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE} from "../../../../contracts/constants/ValidationCodeConstants.sol";

// Strategies
import {StrategyChainlinkFloor} from "../../../../contracts/executionStrategies/Chainlink/StrategyChainlinkFloor.sol";

// Mocks and other tests
import {MockChainlinkAggregator} from "../../../mock/MockChainlinkAggregator.sol";
import {FloorFromChainlinkDiscountOrdersTest} from "./FloorFromChainlinkDiscountOrders.t.sol";

contract FloorFromChainlinkDiscountBasisPointsOrdersTest is FloorFromChainlinkDiscountOrdersTest {
    function setUp() public override {
        _setIsFixedAmount(0);
        _setDiscount(100);
        _setSelector(
            StrategyChainlinkFloor.executeBasisPointsDiscountCollectionOfferStrategyWithTakerAsk.selector,
            true
        );
        super.setUp();
    }

    function testInactiveStrategy() public {
        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        _setPriceFeed();

        _assertOrderIsValid(makerBid);
        _assertValidMakerOrder(makerBid, signature);

        vm.prank(_owner);
        looksRareProtocol.updateStrategy(1, false, _standardProtocolFeeBp, _minTotalFeeBp);

        vm.expectRevert(abi.encodeWithSelector(IExecutionManager.StrategyNotAvailable.selector, 1));
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountBasisPointsDesiredDiscountedPriceGreaterThanOrEqualToMaxPrice() public {
        // Floor price = 9.7 ETH, discount = 1%, desired price = 9.603 ETH
        // Max price = 9.5 ETH
        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        makerBid.price = 9.5 ether;
        takerAsk.additionalParameters = abi.encode(42, 9.5 ether);

        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        _setPriceFeed();

        _assertOrderIsValid(makerBid);
        _assertValidMakerOrder(makerBid, signature);

        _executeTakerAsk(takerAsk, makerBid, signature);

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(42), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 9.5 ether);
        // Taker ask user receives 99.5% of the whole price (0.5% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + 9.4525 ether);
    }

    function testFloorFromChainlinkDiscountBasisPointsDesiredDiscountedPriceLessThanMaxPrice() public {
        // Floor price = 9.7 ETH, discount = 3%, desired price = 9.409 ETH
        // Max price = 9.5 ETH
        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: 300
        });

        makerBid.price = 9.41 ether;

        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        _setPriceFeed();

        _assertOrderIsValid(makerBid);
        _assertValidMakerOrder(makerBid, signature);

        _executeTakerAsk(takerAsk, makerBid, signature);

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(42), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 9.409 ether);
        // Taker ask user receives 99.5% of the whole price (0.5% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + 9.361955 ether);
    }

    function testFloorFromChainlinkDiscountBasisPointsDesiredDiscountBasisPointsGreaterThan10000() public {
        // Floor price = 9.7 ETH, discount = 100%, desired price = 0
        // Max price = 0
        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: ONE_HUNDRED_PERCENT_IN_BP + 1
        });

        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        _setPriceFeed();

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerOrderValid(makerBid, selector);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);

        _assertMakerOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(OrderInvalid.selector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }
}
