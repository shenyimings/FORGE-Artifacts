// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries and interfaces
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";
import {IExecutionManager} from "../../../contracts/interfaces/IExecutionManager.sol";
import {IStrategyManager} from "../../../contracts/interfaces/IStrategyManager.sol";

// Shared errors
import {BidTooLow, OrderInvalid, WrongFunctionSelector} from "../../../contracts/interfaces/SharedErrors.sol";
import {STRATEGY_NOT_ACTIVE, MAKER_ORDER_TEMPORARILY_INVALID_NON_STANDARD_SALE, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE} from "../../../contracts/helpers/ValidationCodeConstants.sol";

// Strategies
import {StrategyDutchAuction} from "../../../contracts/executionStrategies/StrategyDutchAuction.sol";

// Other tests
import {ProtocolBase} from "../ProtocolBase.t.sol";

contract DutchAuctionOrdersTest is ProtocolBase, IStrategyManager {
    StrategyDutchAuction public strategyDutchAuction;
    bytes4 public selector = StrategyDutchAuction.executeStrategyWithTakerBid.selector;

    uint256 private constant startPrice = 10 ether;
    uint256 private constant endPrice = 1 ether;
    uint256 private constant decayPerSecond = 0.0025 ether;

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyDutchAuction = new StrategyDutchAuction();
        looksRareProtocol.addStrategy(
            _standardProtocolFeeBp,
            _minTotalFeeBp,
            _maxProtocolFeeBp,
            selector,
            false,
            address(strategyDutchAuction)
        );
    }

    function _createMakerAskAndTakerBid(
        uint256 numberOfItems,
        uint256 numberOfAmounts
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
            minPrice: endPrice,
            itemId: 1
        });

        newMakerAsk.itemIds = itemIds;
        newMakerAsk.amounts = amounts;

        // 0.0025 ether cheaper per second -> (10 - 1) / 3_600
        newMakerAsk.endTime = block.timestamp + 1 hours;
        newMakerAsk.additionalParameters = abi.encode(startPrice);

        newTakerBid = OrderStructs.TakerBid(takerUser, startPrice, itemIds, amounts, abi.encode());
    }

    function testNewStrategy() public {
        _setUpNewStrategy();

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
        assertEq(strategyImplementation, address(strategyDutchAuction));
    }

    function testDutchAuction(uint256 elapsedTime) public {
        vm.assume(elapsedTime <= 3_600);

        _setUpUsers();
        _setUpNewStrategy();
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid(
            1,
            1
        );

        // Sign order
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.warp(block.timestamp + elapsedTime);

        (bool isValid, bytes4 errorSelector) = strategyDutchAuction.isMakerAskValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);
        _isMakerAskOrderValid(makerAsk, signature);

        // Execute taker bid transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);

        uint256 discount = elapsedTime * decayPerSecond;

        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - startPrice + discount);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + ((startPrice - discount) * 9_800) / 10_000);
    }

    function testInactiveStrategy() public {
        _setUpUsers();
        _setUpNewStrategy();
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid(
            1,
            1
        );

        vm.prank(_owner);
        looksRareProtocol.updateStrategy(1, _standardProtocolFeeBp, _minTotalFeeBp, false);

        // Sign order
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyDutchAuction.isMakerAskValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, STRATEGY_NOT_ACTIVE);

        vm.prank(takerUser);
        vm.expectRevert(abi.encodeWithSelector(IExecutionManager.StrategyNotAvailable.selector, 1));
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testZeroItemIdsLength() public {
        _setUpUsers();
        _setUpNewStrategy();
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid(
            0,
            0
        );

        // Sign order
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyDutchAuction.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testItemIdsAndAmountsLengthMismatch() public {
        _setUpUsers();
        _setUpNewStrategy();
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid(
            1,
            2
        );

        // Sign order
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyDutchAuction.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testItemIdsMismatch() public {
        _setUpUsers();
        _setUpNewStrategy();
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid(
            1,
            1
        );

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 2;

        // Bidder bidding on something else
        takerBid.itemIds = itemIds;

        // Sign order
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyDutchAuction.isMakerAskValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);
        _isMakerAskOrderValid(makerAsk, signature);

        vm.expectRevert(OrderInvalid.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testWrongAmounts() public {
        _setUpUsers();
        _setUpNewStrategy();

        // 1. Amount = 0
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid(
            1,
            1
        );

        makerAsk.amounts[0] = 0;

        // Sign order
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyDutchAuction.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // 2. ERC721 amount > 1
        makerAsk.amounts[0] = 2;
        signature = _signMakerAsk(makerAsk, makerUserPK);

        (isValid, errorSelector) = strategyDutchAuction.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.prank(takerUser);
        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testStartPriceTooLow() public {
        _setUpUsers();
        _setUpNewStrategy();
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid(
            1,
            1
        );

        // startPrice is 10 ether
        makerAsk.minPrice = 10 ether + 1 wei;

        // Sign order
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyDutchAuction.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testTakerBidTooLow(uint256 elapsedTime) public {
        vm.assume(elapsedTime <= 3_600);

        _setUpUsers();
        _setUpNewStrategy();
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid(
            1,
            1
        );

        uint256 currentPrice = startPrice - decayPerSecond * elapsedTime;
        takerBid.maxPrice = currentPrice - 1 wei;

        // Sign order
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyDutchAuction.isMakerAskValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);
        _isMakerAskOrderValid(makerAsk, signature);

        vm.expectRevert(BidTooLow.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testWrongSelector() public {
        _setUpNewStrategy();

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

        (bool orderIsValid, bytes4 errorSelector) = strategyDutchAuction.isMakerAskValid(makerAsk, bytes4(0));
        assertFalse(orderIsValid);
        assertEq(errorSelector, WrongFunctionSelector.selector);
    }
}
