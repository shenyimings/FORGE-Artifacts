// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries and interfaces
import {OrderStructs} from "../../../../contracts/libraries/OrderStructs.sol";
import {IExecutionManager} from "../../../../contracts/interfaces/IExecutionManager.sol";
import {IStrategyManager} from "../../../../contracts/interfaces/IStrategyManager.sol";

// Shared errors
import {BidTooLow, OrderInvalid, WrongCurrency, WrongFunctionSelector} from "../../../../contracts/interfaces/SharedErrors.sol";

// Strategies
import {StrategyUSDDynamicAsk} from "../../../../contracts/executionStrategies/Chainlink/StrategyUSDDynamicAsk.sol";
import {BaseStrategyChainlinkPriceLatency} from "../../../../contracts/executionStrategies/Chainlink/BaseStrategyChainlinkPriceLatency.sol";

// Mocks and other tests
import {MockChainlinkAggregator} from "../../../mock/MockChainlinkAggregator.sol";
import {MockERC20} from "../../../mock/MockERC20.sol";
import {ProtocolBase} from "../../ProtocolBase.t.sol";
import {ChainlinkMaximumLatencyTest} from "./ChainlinkMaximumLatency.t.sol";

contract USDDynamicAskOrdersTest is ProtocolBase, IStrategyManager, ChainlinkMaximumLatencyTest {
    StrategyUSDDynamicAsk public strategyUSDDynamicAsk;
    bytes4 public selector = StrategyUSDDynamicAsk.executeStrategyWithTakerBid.selector;

    // At block 15740567
    // roundId         uint80  :  92233720368547793259
    // answer          int256  :  126533075631
    // startedAt       uint256 :  1665680123
    // updatedAt       uint256 :  1665680123
    // answeredInRound uint80  :  92233720368547793259
    uint256 private constant FORKED_BLOCK_NUMBER = 15740567;
    uint256 private constant LATEST_CHAINLINK_ANSWER_IN_WAD = 126533075631 * 1e10;

    function setUp() public override {
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORKED_BLOCK_NUMBER);
        super.setUp();
        _setUpUsers();
        _setUpNewStrategy();
    }

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyUSDDynamicAsk = new StrategyUSDDynamicAsk(
            _owner,
            address(weth),
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419 // Mainnet address of the Chainlink price feed
        );

        looksRareProtocol.addStrategy(
            _standardProtocolFeeBp,
            _minTotalFeeBp,
            _maxProtocolFeeBp,
            selector,
            false,
            address(strategyUSDDynamicAsk)
        );
    }

    function _createMakerAskAndTakerBid(
        uint256 numberOfItems,
        uint256 numberOfAmounts,
        uint256 desiredSalePriceInUSD
    ) private returns (OrderStructs.MakerAsk memory newMakerAsk, OrderStructs.TakerBid memory newTakerBid) {
        uint256[] memory itemIds = new uint256[](numberOfItems);
        for (uint256 i; i < numberOfItems; ) {
            mockERC721.mint(makerUser, i + 1);
            itemIds[i] = i + 1;
            unchecked {
                ++i;
            }
        }

        uint256[] memory amounts = new uint256[](numberOfAmounts);
        for (uint256 i; i < numberOfAmounts; ) {
            amounts[i] = 1;
            unchecked {
                ++i;
            }
        }

        // Prepare the order hash
        newMakerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            assetType: 0,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            minPrice: 0.99 ether,
            itemId: 1
        });

        newMakerAsk.itemIds = itemIds;
        newMakerAsk.amounts = amounts;
        newMakerAsk.additionalParameters = abi.encode(desiredSalePriceInUSD);

        newTakerBid = OrderStructs.TakerBid(takerUser, 1 ether, itemIds, amounts, abi.encode());
    }

    function testNewStrategy() public {
        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelector,
            bool strategyIsMakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(1);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFeeBp);
        assertEq(strategyMinTotalFee, _minTotalFeeBp);
        assertEq(strategyMaxProtocolFee, _maxProtocolFeeBp);
        assertEq(strategySelector, selector);
        assertFalse(strategyIsMakerBid);
        assertEq(strategyImplementation, address(strategyUSDDynamicAsk));
    }

    function testSetMaximumLatency() public {
        _testSetMaximumLatency(address(strategyUSDDynamicAsk));
    }

    function testSetMaximumLatencyLatencyToleranceTooHigh() public {
        _testSetMaximumLatencyLatencyToleranceTooHigh(address(strategyUSDDynamicAsk));
    }

    function testSetMaximumLatencyNotOwner() public {
        _testSetMaximumLatencyNotOwner(address(strategyUSDDynamicAsk));
    }

    function testUSDDynamicAskInvalidChainlinkPrice() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.updateMaxLatency(3_600);

        MockChainlinkAggregator priceFeed = new MockChainlinkAggregator();
        vm.etch(CHAINLINK_ETH_USD_PRICE_FEED, address(priceFeed).code);

        MockChainlinkAggregator(CHAINLINK_ETH_USD_PRICE_FEED).setAnswer(-1);
        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, BaseStrategyChainlinkPriceLatency.InvalidChainlinkPrice.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        MockChainlinkAggregator(CHAINLINK_ETH_USD_PRICE_FEED).setAnswer(0);
        (isValid, errorSelector) = strategyUSDDynamicAsk.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, BaseStrategyChainlinkPriceLatency.InvalidChainlinkPrice.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testUSDDynamicAskUSDValueGreaterThanOrEqualToMinAcceptedEthValue() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.updateMaxLatency(3_600);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerAskValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        // Execute taker bid transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);
        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 1 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 0.98 ether);
    }

    function testUSDDynamicAskUSDValueLessThanMinAcceptedEthValue() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: (LATEST_CHAINLINK_ANSWER_IN_WAD * 98) / 100
        });

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.updateMaxLatency(3_600);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerAskValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        // Execute taker bid transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);

        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 0.99 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 0.9702 ether);
    }

    // This tests that we can handle fractions
    function testUSDDynamicAskUSDValueLessThanOneETH() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD / 2
        });

        makerAsk.minPrice = 0.49 ether;

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.updateMaxLatency(3_600);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerAskValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        // Execute taker bid transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);

        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 0.5 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 0.49 ether);
    }

    function testUSDDynamicAskBidderOverpaid() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        // Make the order currency native ETH
        makerAsk.currency = address(0);
        // Bidder overpays by 0.1 ETH
        takerBid.maxPrice = 1.1 ether;

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.updateMaxLatency(3_600);

        uint256 initialETHBalanceTakerUser = address(takerUser).balance;
        uint256 initialETHBalanceMakerUser = address(makerUser).balance;

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerAskValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        // Execute taker bid transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid{value: takerBid.maxPrice}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);
        // Taker bid user pays the whole price, but without overpaying
        assertEq(address(takerUser).balance, initialETHBalanceTakerUser - 1 ether - 1);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(address(makerUser).balance, initialETHBalanceMakerUser + 0.98 ether);
    }

    function testOraclePriceNotRecentEnough() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, BaseStrategyChainlinkPriceLatency.PriceNotRecentEnough.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testCannotExecuteIfNotWETHOrETH() public {
        MockERC20 fakeCurrency = new MockERC20();
        vm.prank(_owner);
        looksRareProtocol.updateCurrencyWhitelistStatus(address(fakeCurrency), true);

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        // Adjust the currency to something creative
        makerAsk.currency = address(fakeCurrency);

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, WrongCurrency.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testZeroItemIdsLength() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 0,
            numberOfAmounts: 0,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.updateMaxLatency(3_600);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testItemIdsAndAmountsLengthMismatch() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 2,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.updateMaxLatency(3_600);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testItemIdsMismatch() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 2;

        // Bidder bidding on something else
        takerBid.itemIds = itemIds;

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.updateMaxLatency(3_600);

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerAskValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        vm.expectRevert(OrderInvalid.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testZeroAmount() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        makerAsk.amounts = amounts;
        takerBid.amounts = amounts;

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.updateMaxLatency(3_600);

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);

        vm.prank(takerUser);
        vm.expectRevert(errorSelector);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testAmountGreaterThanOneForERC721() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;
        makerAsk.amounts = amounts;
        takerBid.amounts = amounts;

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.updateMaxLatency(3_600);

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);

        vm.prank(takerUser);
        vm.expectRevert(errorSelector);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testTakerBidTooLow() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        takerBid.maxPrice = 0.99 ether;

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.updateMaxLatency(3_600);

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerAskValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        vm.expectRevert(BidTooLow.selector);
        vm.prank(takerUser);

        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testInactiveStrategy() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyUSDDynamicAsk.updateMaxLatency(3_600);
        looksRareProtocol.updateStrategy(1, _standardProtocolFeeBp, _minTotalFeeBp, false);
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerAskValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        vm.expectRevert(abi.encodeWithSelector(IExecutionManager.StrategyNotAvailable.selector, 1));
        vm.prank(takerUser);

        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testWrongSelector() public {
        OrderStructs.MakerAsk memory makerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 2,
            assetType: 0,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            minPrice: 1 ether,
            itemId: 0
        });

        (bool orderIsValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerAskValid(makerAsk, bytes4(0));
        assertFalse(orderIsValid);
        assertEq(errorSelector, WrongFunctionSelector.selector);
    }
}
