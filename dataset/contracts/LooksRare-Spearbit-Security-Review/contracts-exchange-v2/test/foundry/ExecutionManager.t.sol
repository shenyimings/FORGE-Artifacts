// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Libraries and interfaces
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IExecutionManager} from "../../contracts/interfaces/IExecutionManager.sol";
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";

// Shared errors
import {OrderInvalid} from "../../contracts/interfaces/SharedErrors.sol";
import {START_TIME_GREATER_THAN_END_TIME, TOO_LATE_TO_EXECUTE_ORDER, TOO_EARLY_TO_EXECUTE_ORDER} from "../../contracts/helpers/ValidationCodeConstants.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Strategies
import {StrategyFloorFromChainlink} from "../../contracts/executionStrategies/Chainlink/StrategyFloorFromChainlink.sol";

contract ExecutionManagerTest is ProtocolBase, IExecutionManager, IStrategyManager {
    function testUpdateCreatorFeeManager() public asPrankedUser(_owner) {
        vm.expectEmit(true, false, false, true);
        emit NewCreatorFeeManager(address(1));
        looksRareProtocol.updateCreatorFeeManager(address(1));
        assertEq(address(looksRareProtocol.creatorFeeManager()), address(1));
    }

    function testUpdateCreatorFeeManagerNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.updateCreatorFeeManager(address(1));
    }

    function testUpdateMaxCreatorFeeBp() public asPrankedUser(_owner) {
        uint16 newMaxCreatorFeeBp = uint16(2_500);
        vm.expectEmit(true, false, false, true);
        emit NewMaxCreatorFeeBp(newMaxCreatorFeeBp);
        looksRareProtocol.updateMaxCreatorFeeBp(newMaxCreatorFeeBp);
        assertEq(looksRareProtocol.maxCreatorFeeBp(), newMaxCreatorFeeBp);
    }

    function testUpdateMaxCreatorFeeBpNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.updateMaxCreatorFeeBp(uint16(2_500));
    }

    function testUpdateMaxCreatorFeeBpTooHigh() public asPrankedUser(_owner) {
        vm.expectRevert(CreatorFeeBpTooHigh.selector);
        looksRareProtocol.updateMaxCreatorFeeBp(uint16(2_501));
    }

    function testUpdateProtocolFeeRecipient() public asPrankedUser(_owner) {
        vm.expectEmit(true, false, false, true);
        emit NewProtocolFeeRecipient(address(1));
        looksRareProtocol.updateProtocolFeeRecipient(address(1));
        assertEq(looksRareProtocol.protocolFeeRecipient(), address(1));
    }

    function testUpdateProtocolFeeRecipientCannotBeNullAddress() public asPrankedUser(_owner) {
        vm.expectRevert(IExecutionManager.NewProtocolFeeRecipientCannotBeNullAddress.selector);
        looksRareProtocol.updateProtocolFeeRecipient(address(0));
    }

    function testUpdateProtocolFeeRecipientNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.updateProtocolFeeRecipient(address(1));
    }

    function testCannotValidateOrderIfWrongTimestamps() public asPrankedUser(takerUser) {
        // Change timestamp to avoid underflow issues
        vm.warp(12_000_000);

        /**
         * 1. Too early to execute
         */
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            address(weth)
        );

        makerBid.startTime = block.timestamp + 20 minutes;
        makerBid.endTime = block.timestamp + 21 minutes;

        vm.warp(makerBid.startTime - 5 minutes);
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);
        _doesMakerBidOrderReturnValidationCode(makerBid, signature, TOO_EARLY_TO_EXECUTE_ORDER);

        vm.warp(makerBid.startTime - 1);
        vm.expectRevert(OutsideOfTimeRange.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        /**
         * 2. Too late to execute
         */

        makerBid.startTime = 0;
        makerBid.endTime = block.timestamp;
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.warp(block.timestamp);
        _doesMakerBidOrderReturnValidationCode(makerBid, signature, TOO_LATE_TO_EXECUTE_ORDER);

        vm.warp(block.timestamp + 1);
        vm.expectRevert(OutsideOfTimeRange.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        /**
         * 3. start time > end time
         */
        makerBid.startTime = block.timestamp + 1;
        makerBid.endTime = block.timestamp;
        signature = _signMakerBid(makerBid, makerUserPK);

        _doesMakerBidOrderReturnValidationCode(makerBid, signature, START_TIME_GREATER_THAN_END_TIME);

        vm.expectRevert(OutsideOfTimeRange.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testCannotValidateOrderIfWrongFormat() public asPrankedUser(takerUser) {
        // (For takerBid tests)
        vm.deal(takerUser, 100 ether);

        uint256[] memory itemIds = new uint256[](2);

        /**
         * 1. STANDARD STRATEGY/MAKER BID: itemIds' length is equal to 0
         */
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            address(weth)
        );

        // Change makerBid itemIds array's length to make it equal to 0
        itemIds = new uint256[](0);
        makerBid.itemIds = itemIds;
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        /**
         * 2. STANDARD STRATEGY/MAKER BID: maker itemIds' length is not equal to maker amounts' length
         */
        (makerBid, takerAsk) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));

        // Change itemIds array for maker to make its length equal to 2
        itemIds = new uint256[](2);
        makerBid.itemIds = itemIds;
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        /**
         * 3. STANDARD STRATEGY/MAKER BID: itemIds' length of maker is not equal to length of taker
         */
        (makerBid, takerAsk) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));

        // Change itemIds array for taker to make its length equal to 2
        itemIds = new uint256[](2);
        takerAsk.itemIds = itemIds;
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        /**
         * 4. STANDARD STRATEGY/MAKER BID: amounts' length of maker is not equal to length of taker
         */
        (makerBid, takerAsk) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));

        // Change amounts array for taker to make its length equal to 2
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;
        takerAsk.amounts = amounts;
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        /**
         * 5. STANDARD STRATEGY/MAKER BID: maxPrice of maker is not equal to minPrice of taker
         */
        (makerBid, takerAsk) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));
        signature = _signMakerBid(makerBid, makerUserPK);

        // Change price of takerAsk to be higher than makerAsk price
        takerAsk.minPrice = makerBid.maxPrice + 1;

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Change price of takerAsk to be higher than makerAsk price
        takerAsk.minPrice = makerBid.maxPrice - 1;

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        /**
         * 6. STANDARD STRATEGY/MAKER ASK: itemIds' length of maker is equal to 0
         */
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMockMakerAskAndTakerBid(
            address(mockERC721)
        );

        // Change maker itemIds array to make its length equal to 0
        itemIds = new uint256[](0);
        makerAsk.itemIds = itemIds;
        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerBid{value: takerBid.maxPrice}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        /**
         * 7. STANDARD STRATEGY/MAKER ASK: maker itemIds' length is not equal to maker amounts' length
         */
        (makerAsk, takerBid) = _createMockMakerAskAndTakerBid(address(mockERC721));

        // Change itemIds array to make it equal to 2
        itemIds = new uint256[](2);
        makerAsk.itemIds = itemIds;
        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerBid{value: takerBid.maxPrice}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        /**
         * 8. STANDARD STRATEGY/MAKER ASK: itemIds' length of maker is not equal to length of taker
         */
        (makerAsk, takerBid) = _createMockMakerAskAndTakerBid(address(mockERC721));

        // Change itemIds array to make it equal to 2
        itemIds = new uint256[](2);
        takerBid.itemIds = itemIds;
        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerBid{value: takerBid.maxPrice}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        /**
         * 9. STANDARD STRATEGY/MAKER ASK: amounts' length of maker is not equal to length of taker
         */

        // Change amounts array' length to make it equal to 2
        (makerAsk, takerBid) = _createMockMakerAskAndTakerBid(address(mockERC721));
        amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;
        takerBid.amounts = amounts;
        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerBid{value: takerBid.maxPrice}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        /**
         * 10. STANDARD STRATEGY/MAKER ASK: minPrice of maker is not equal to maxPrice of taker
         */
        (makerAsk, takerBid) = _createMockMakerAskAndTakerBid(address(mockERC721));
        signature = _signMakerAsk(makerAsk, makerUserPK);

        // Change price of takerBid to be lower than makerAsk price
        takerBid.maxPrice = makerAsk.minPrice - 1;

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerBid{value: takerBid.maxPrice}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        // Change price of takerBid to be higher than makerAsk price
        takerBid.maxPrice = makerAsk.minPrice + 1;

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerBid{value: takerBid.maxPrice}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }

    function testCannotExecuteTransactionIfMakerBidWithStrategyForMakerAsk() public {
        _setUpUsers();

        vm.prank(_owner);
        StrategyFloorFromChainlink strategy = new StrategyFloorFromChainlink(_owner, address(weth));

        bool isMakerBid = true;
        vm.prank(_owner);
        looksRareProtocol.addStrategy(
            250,
            250,
            300,
            StrategyFloorFromChainlink.executeBasisPointsDiscountCollectionOfferStrategyWithTakerAsk.selector,
            isMakerBid,
            address(strategy)
        );

        uint256 itemId = 0;
        uint256 price = 1 ether;

        // Mint asset
        mockERC721.mint(makerUser, itemId);

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid, bytes memory signature) = _createSingleItemMakerAskAndTakerBidOrderAndSignature({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 1, // Fake strategy
            assetType: 0,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(0),
            signer: makerUser,
            minPrice: price,
            itemId: itemId
        });

        vm.prank(takerUser);
        vm.expectRevert(IExecutionManager.NoSelectorForMakerAsk.selector);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }

    function testCannotExecuteTransactionIfMakerAskWithStrategyForMakerBid() public {
        _setUpUsers();

        vm.prank(_owner);
        StrategyFloorFromChainlink strategy = new StrategyFloorFromChainlink(_owner, address(weth));

        bool isMakerBid = false;
        vm.prank(_owner);
        // All parameters are random, including the selector and the implementation
        looksRareProtocol.addStrategy(
            250,
            250,
            300,
            StrategyFloorFromChainlink.executeFixedPremiumStrategyWithTakerBid.selector,
            isMakerBid,
            address(strategy)
        );

        uint256 itemId = 0;
        uint256 price = 1 ether;

        // Mint asset to ask user
        mockERC721.mint(takerUser, itemId);

        // Prepare the order hash
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk, bytes memory signature) = _createSingleItemMakerBidAndTakerAskOrderAndSignature({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 1, // Fake strategy
            assetType: 0,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: itemId
        });

        vm.prank(takerUser);
        vm.expectRevert(IExecutionManager.NoSelectorForMakerBid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }
}
