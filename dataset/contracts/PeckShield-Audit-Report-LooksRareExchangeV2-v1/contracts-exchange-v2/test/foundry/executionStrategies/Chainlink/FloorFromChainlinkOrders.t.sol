// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// LooksRare libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Libraries and interfaces
import {OrderStructs} from "../../../../contracts/libraries/OrderStructs.sol";
import {IStrategyManager} from "../../../../contracts/interfaces/IStrategyManager.sol";

// Errors and constants
import {FunctionSelectorInvalid, QuoteTypeInvalid} from "../../../../contracts/errors/SharedErrors.sol";
import {DecimalsInvalid, PriceFeedAlreadySet} from "../../../../contracts/errors/ChainlinkErrors.sol";
import {ONE_HUNDRED_PERCENT_IN_BP} from "../../../../contracts/constants/NumericConstants.sol";

// Strategies
import {StrategyChainlinkFloor} from "../../../../contracts/executionStrategies/Chainlink/StrategyChainlinkFloor.sol";

// Mocks and other tests
import {MockChainlinkAggregator} from "../../../mock/MockChainlinkAggregator.sol";
import {ProtocolBase} from "../../ProtocolBase.t.sol";

// Enums
import {CollectionType} from "../../../../contracts/enums/CollectionType.sol";
import {QuoteType} from "../../../../contracts/enums/QuoteType.sol";

abstract contract FloorFromChainlinkOrdersTest is ProtocolBase, IStrategyManager {
    StrategyChainlinkFloor internal strategyFloorFromChainlink;

    // At block 15740567
    // roundId         uint80  : 18446744073709552305
    // answer          int256  : 9700000000000000000
    // startedAt       uint256 : 1666100016
    // updatedAt       uint256 : 1666100016
    // answeredInRound uint80  : 18446744073709552305
    uint256 internal constant CHAINLINK_PRICE_UPDATED_AT = 1666100016;
    uint256 private constant FORKED_BLOCK_NUMBER = 7_791_270;
    uint256 internal constant LATEST_CHAINLINK_ANSWER_IN_WAD = 9.7 ether;
    uint256 internal constant MAXIMUM_LATENCY = 86_400 seconds;
    address internal constant AZUKI_PRICE_FEED = 0x9F6d70CDf08d893f0063742b51d3E9D1e18b7f74;

    uint256 private isFixedAmount;
    bytes4 internal selector;
    bool internal isMakerBid;

    function setUp() public virtual {
        vm.createSelectFork(vm.rpcUrl("goerli"), FORKED_BLOCK_NUMBER);
        _setUp();
        _setUpUsers();
        _setUpNewStrategy();
    }

    function testNewStrategy() public {
        _assertStrategyAttributes(address(strategyFloorFromChainlink), selector, isMakerBid);
    }

    function testMaxLatency() public {
        assertEq(strategyFloorFromChainlink.maxLatency(), MAXIMUM_LATENCY);
    }

    event PriceFeedUpdated(address indexed collection, address indexed priceFeed);

    function testSetPriceFeed() public asPrankedUser(_owner) {
        vm.expectEmit({checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: false});
        emit PriceFeedUpdated(address(mockERC721), AZUKI_PRICE_FEED);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        assertEq(strategyFloorFromChainlink.priceFeeds(address(mockERC721)), AZUKI_PRICE_FEED);
    }

    function testSetPriceFeedDecimalsInvalid(uint8 decimals) public asPrankedUser(_owner) {
        vm.assume(decimals != 18);

        MockChainlinkAggregator priceFeed = new MockChainlinkAggregator();
        priceFeed.setDecimals(decimals);
        vm.expectRevert(DecimalsInvalid.selector);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), address(priceFeed));
    }

    function testPriceFeedCannotBeSetTwice() public asPrankedUser(_owner) {
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.expectRevert(PriceFeedAlreadySet.selector);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
    }

    function testSetPriceFeedNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
    }

    function testQuoteTypeInvalid() public {
        OrderStructs.Maker memory maker;

        // 1. Maker bid, but function selector is for maker ask
        maker.quoteType = QuoteType.Bid;

        (bool orderIsValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerOrderValid(
            maker,
            StrategyChainlinkFloor.executeBasisPointsPremiumStrategyWithTakerBid.selector
        );
        assertFalse(orderIsValid);
        assertEq(errorSelector, QuoteTypeInvalid.selector);

        (orderIsValid, errorSelector) = strategyFloorFromChainlink.isMakerOrderValid(
            maker,
            StrategyChainlinkFloor.executeFixedPremiumStrategyWithTakerBid.selector
        );
        assertFalse(orderIsValid);
        assertEq(errorSelector, QuoteTypeInvalid.selector);

        // 2. Maker ask, but function selector is for maker bid
        maker.quoteType = QuoteType.Ask;

        (orderIsValid, errorSelector) = strategyFloorFromChainlink.isMakerOrderValid(
            maker,
            StrategyChainlinkFloor.executeBasisPointsDiscountCollectionOfferStrategyWithTakerAsk.selector
        );
        assertFalse(orderIsValid);
        assertEq(errorSelector, QuoteTypeInvalid.selector);

        (orderIsValid, errorSelector) = strategyFloorFromChainlink.isMakerOrderValid(
            maker,
            StrategyChainlinkFloor.executeFixedDiscountCollectionOfferStrategyWithTakerAsk.selector
        );
        assertFalse(orderIsValid);
        assertEq(errorSelector, QuoteTypeInvalid.selector);
    }

    function testInvalidSelector() public {
        OrderStructs.Maker memory makerAsk = _createSingleItemMakerOrder({
            quoteType: QuoteType.Ask,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: 2,
            collectionType: CollectionType.ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            price: 1 ether,
            itemId: 420
        });

        (bool orderIsValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerOrderValid(makerAsk, bytes4(0));
        assertFalse(orderIsValid);
        assertEq(errorSelector, FunctionSelectorInvalid.selector);

        OrderStructs.Maker memory makerBid = _createSingleItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: 2,
            collectionType: CollectionType.ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            price: 1 ether,
            itemId: 420
        });

        (orderIsValid, errorSelector) = strategyFloorFromChainlink.isMakerOrderValid(makerBid, bytes4(0));
        assertFalse(orderIsValid);
        assertEq(errorSelector, FunctionSelectorInvalid.selector);
    }

    function _setSelector(bytes4 _selector, bool _isMakerBid) internal {
        selector = _selector;
        isMakerBid = _isMakerBid;
    }

    function _createMakerAskAndTakerBid(
        uint256 premium
    ) internal returns (OrderStructs.Maker memory newMakerAsk, OrderStructs.Taker memory newTakerBid) {
        mockERC721.mint(makerUser, 1);

        newMakerAsk = _createSingleItemMakerOrder({
            quoteType: QuoteType.Ask,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            collectionType: CollectionType.ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            price: LATEST_CHAINLINK_ANSWER_IN_WAD,
            itemId: 1
        });

        newMakerAsk.additionalParameters = abi.encode(premium);

        uint256 maxPrice = isFixedAmount != 0
            ? LATEST_CHAINLINK_ANSWER_IN_WAD + premium
            : (LATEST_CHAINLINK_ANSWER_IN_WAD * (ONE_HUNDRED_PERCENT_IN_BP + premium)) / ONE_HUNDRED_PERCENT_IN_BP;

        newTakerBid = OrderStructs.Taker(takerUser, abi.encode(maxPrice));
    }

    function _createMakerBidAndTakerAsk(
        uint256 discount
    ) internal returns (OrderStructs.Maker memory newMakerBid, OrderStructs.Taker memory newTakerAsk) {
        mockERC721.mint(takerUser, 42);

        uint256 price;
        if (isFixedAmount != 0) {
            price = LATEST_CHAINLINK_ANSWER_IN_WAD - discount;
        } else {
            if (discount > ONE_HUNDRED_PERCENT_IN_BP) {
                price = 0;
            } else {
                price =
                    (LATEST_CHAINLINK_ANSWER_IN_WAD * (ONE_HUNDRED_PERCENT_IN_BP - discount)) /
                    ONE_HUNDRED_PERCENT_IN_BP;
            }
        }

        newMakerBid = _createSingleItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            collectionType: CollectionType.ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            price: price,
            itemId: 0 // Doesn't matter, not used
        });

        newMakerBid.additionalParameters = abi.encode(discount);

        newTakerAsk = OrderStructs.Taker({recipient: takerUser, additionalParameters: abi.encode(42, price)});
    }

    function _setIsFixedAmount(uint256 _isFixedAmount) internal {
        isFixedAmount = _isFixedAmount;
    }

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyFloorFromChainlink = new StrategyChainlinkFloor(_owner, address(weth));
        _addStrategy(address(strategyFloorFromChainlink), selector, isMakerBid);
    }

    function _setPriceFeed() internal asPrankedUser(_owner) {
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
    }
}
