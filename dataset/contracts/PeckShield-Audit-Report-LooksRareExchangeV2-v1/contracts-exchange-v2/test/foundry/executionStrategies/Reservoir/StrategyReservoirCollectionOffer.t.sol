// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Murky (third-party) library is used to compute Merkle trees in Solidity
import {Merkle} from "../../../../lib/murky/src/Merkle.sol";

// LooksRare unopinionated libraries
import {IERC721} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC721.sol";

// Libraries
import {OrderStructs} from "../../../../contracts/libraries/OrderStructs.sol";

// Errors and constants
import {AmountInvalid, FunctionSelectorInvalid, MerkleProofInvalid, OrderInvalid, QuoteTypeInvalid} from "../../../../contracts/errors/SharedErrors.sol";
import {ItemIdFlagged, ItemTransferredTooRecently, LastTransferTimeInvalid, MessageIdInvalid, SignatureExpired, TransferCooldownPeriodTooHigh} from "../../../../contracts/errors/ReservoirErrors.sol";
import {MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE} from "../../../../contracts/constants/ValidationCodeConstants.sol";
import {ONE_HUNDRED_PERCENT_IN_BP} from "../../../../contracts/constants/NumericConstants.sol";

// Strategies
import {StrategyReservoirCollectionOffer} from "../../../../contracts/executionStrategies/Reservoir/StrategyReservoirCollectionOffer.sol";

// Enums
import {CollectionType} from "../../../../contracts/enums/CollectionType.sol";
import {QuoteType} from "../../../../contracts/enums/QuoteType.sol";

// Base test
import {ProtocolBase} from "../../ProtocolBase.t.sol";

contract CollectionOffersWithReservoirTest is ProtocolBase {
    StrategyReservoirCollectionOffer public strategyReservoirCollectionOffer;

    // Constants from the strategy contract
    uint256 public constant SIGNATURE_VALIDITY_PERIOD = 90 seconds;
    uint256 public constant MAXIMUM_TRANSFER_COOLDOWN_PERIOD = 24 hours;

    // Selectors
    bytes4 public immutable selectorNoProof =
        strategyReservoirCollectionOffer.executeCollectionStrategyWithTakerAsk.selector;
    bytes4 public immutable selectorWithProof =
        strategyReservoirCollectionOffer.executeCollectionStrategyWithTakerAskWithProof.selector;

    // Other test parameters
    uint256 private constant price = 1 ether; // Fixed price of sale
    uint256 private constant defaultTransferCooldownPeriod = 1 hours; // Default transfer cooldown period

    function testNewStrategies() public {
        _setUp();
        _setUpNewStrategies();

        assertEq(strategyReservoirCollectionOffer.SIGNATURE_VALIDITY_PERIOD(), SIGNATURE_VALIDITY_PERIOD);
        assertEq(strategyReservoirCollectionOffer.MAXIMUM_TRANSFER_COOLDOWN_PERIOD(), MAXIMUM_TRANSFER_COOLDOWN_PERIOD);

        for (uint256 i = 1; i < 3; i++) {
            (
                bool strategyIsActive,
                uint16 strategyStandardProtocolFee,
                uint16 strategyMinTotalFee,
                uint16 strategyMaxProtocolFee,
                bytes4 strategySelector,
                bool strategyIsMakerBid,
                address strategyImplementation
            ) = looksRareProtocol.strategyInfo(i);

            assertTrue(strategyIsActive);
            assertEq(strategyStandardProtocolFee, _standardProtocolFeeBp);
            assertEq(strategyMinTotalFee, _minTotalFeeBp);
            assertEq(strategyMaxProtocolFee, _maxProtocolFeeBp);
            assertEq(strategySelector, i == 1 ? selectorNoProof : selectorWithProof);
            assertTrue(strategyIsMakerBid);
            assertEq(strategyImplementation, address(strategyReservoirCollectionOffer));
        }
    }

    function testCollectionOrderRevertsIfItemIsFlagged() public {
        _testRevertsIfItemIsFlagged(false);
    }

    function testCollectionOrderWithMerkleTreeRevertsIfItemIsFlagged() public {
        _testRevertsIfItemIsFlagged(true);
    }

    function testCollectionOrderWorksIfItemIsNotFlaggedAndLastTransferIsRecentEnough() public {
        _testWorksIfItemIsNotFlaggedAndLastTransferIsRecentEnough(false);
    }

    function testCollectionOrderWithMerkleTreeWorksIfItemIsNotFlaggedAndLastTransferIsRecentEnough() public {
        _testWorksIfItemIsNotFlaggedAndLastTransferIsRecentEnough(true);
    }

    function testCollectionOrderRevertsIfLastTransferTimeIsZero() public {
        _testRevertsIfLastTransferTimeIsZero(false);
    }

    function testCollectionOrderWithMerkleTreeRevertsIfLastTransferTimeIsZero() public {
        _testRevertsIfLastTransferTimeIsZero(true);
    }

    function testCollectionOrderRevertsIfSignatureExpires() public {
        _testRevertsIfSignatureExpires(false);
    }

    function testCollectionOrderWithMerkleTreeRevertsIfSignatureExpires() public {
        _testRevertsIfSignatureExpires(true);
    }

    function testCollectionOrderRevertsIfTransferWithinCooldownPeriodOrTransferCooldownPeriodTooHigh() public {
        _testRevertsIfTransferWithinCooldownPeriodOrTransferCooldownPeriodTooHigh(false);
    }

    function testCollectionOrderWithMerkleTreeRevertsIfTransferWithinCooldownPeriodOrTransferCooldownPeriodTooHigh()
        public
    {
        _testRevertsIfTransferWithinCooldownPeriodOrTransferCooldownPeriodTooHigh(true);
    }

    function testCollectionOrderRevertsIfItemIdDiffers(uint16 itemId) public {
        _testCollectionOrderRevertsIfItemIdDiffers(false, itemId);
    }

    function testCollectionOrderWithMerkleTreeRevertsIfItemIdDiffers(uint16 itemId) public {
        _testCollectionOrderRevertsIfItemIdDiffers(true, itemId);
    }

    function testCollectionOrderRevertsIfCollectionTypeIsNotERC721() public {
        _testRevertsIfCollectionTypeIsNotERC721(false);
    }

    function testCollectionOrderWithMerkleTreeRevertsIfCollectionTypeIsNotERC721() public {
        _testRevertsIfCollectionTypeIsNotERC721(true);
    }

    function testCollectionOrdersAmountsInvalid() public {
        _testAmountsInvalid(false);
    }

    function testCollectionOrdersWithMerkleTreeAmountsInvalid() public {
        _testAmountsInvalid(true);
    }

    function testCollectionOrdersAdditionalParametersLengthInvalid() public {
        _testAdditionalParametersLengthInvalid(false);
    }

    function testCollectionOrdersWithMerkleTreeAdditionalParametersLengthInvalid() public {
        _testAdditionalParametersLengthInvalid(true);
    }

    function testCollectionOrdersWithMerkleTreeRevertsWithInvalidMerkleProof(uint16 randomItemId) public {
        uint256 numberOfItemsInMerkleTree = 1000;

        // 420 is the itemId that is from the Reservoir's data
        vm.assume(randomItemId != 420 && randomItemId < numberOfItemsInMerkleTree);

        (
            uint256 forkedBlockNumber,
            ,
            address collection,
            ,
            address itemOwner,
            ,
            bytes memory takerAdditionalParameters
        ) = _returnValidNonFlaggedItemDataFromReservoir();

        _setUpForkAtBlockNumber(forkedBlockNumber);
        _setUpUser(makerUser);
        _setUpTakerUserAndGrantApprovals(itemOwner, collection);

        OrderStructs.Maker memory makerBid = _createSingleItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: 2,
            collectionType: CollectionType.ERC721,
            orderNonce: 0,
            collection: collection,
            currency: address(weth),
            signer: makerUser,
            price: price,
            itemId: 0
        });

        // Initialize the merkle tree object
        Merkle m = new Merkle();

        bytes32[] memory merkleTreeIds = new bytes32[](numberOfItemsInMerkleTree);
        for (uint256 i; i < numberOfItemsInMerkleTree; i++) {
            merkleTreeIds[i] = keccak256(abi.encodePacked(i));
        }

        // Compute the merkle root
        bytes32 merkleRoot = m.getRoot(merkleTreeIds);

        // Pick random proof that is not the correct one
        bytes32[] memory proof = m.getProof(merkleTreeIds, randomItemId);
        makerBid.additionalParameters = abi.encode(merkleRoot, defaultTransferCooldownPeriod);

        // Add the proof to the taker additional parameters and generate the Taker struct
        takerAdditionalParameters = _addProofToTakerAdditionalParameters(takerAdditionalParameters, proof);

        // Sign order and prepare taker ask
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);
        OrderStructs.Taker memory takerAsk = OrderStructs.Taker(takerUser, takerAdditionalParameters);

        // Verify validity of maker bid order
        // @dev It is still valid because the merkle root is properly defined (type-wise)
        _assertOrderIsValid(makerBid, true);
        _assertValidMakerOrder(makerBid, signature);

        vm.prank(itemOwner);
        vm.expectRevert(MerkleProofInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testWrongQuoteType() public {
        _setUp();
        _setUpNewStrategies();

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
            price: price,
            itemId: 0
        });

        (bool orderIsValid, bytes4 errorSelector) = strategyReservoirCollectionOffer.isMakerOrderValid(
            makerAsk,
            selectorNoProof
        );

        assertFalse(orderIsValid);
        assertEq(errorSelector, QuoteTypeInvalid.selector);
    }

    function testInvalidSelector() public {
        _setUp();
        _setUpNewStrategies();

        OrderStructs.Maker memory makerBid = _createSingleItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: 3,
            collectionType: CollectionType.ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            price: price,
            itemId: 0
        });

        (bool orderIsValid, bytes4 errorSelector) = strategyReservoirCollectionOffer.isMakerOrderValid(
            makerBid,
            bytes4(0)
        );

        assertFalse(orderIsValid);
        assertEq(errorSelector, FunctionSelectorInvalid.selector);
    }

    function _testWorksIfItemIsNotFlaggedAndLastTransferIsRecentEnough(bool withMerkleTreeCriteria) internal {
        (
            uint256 forkedBlockNumber,
            ,
            address collection,
            uint256 itemId,
            address itemOwner,
            ,
            bytes memory takerAdditionalParameters
        ) = _returnValidNonFlaggedItemDataFromReservoir();

        _setUpForkAtBlockNumber(forkedBlockNumber);
        _setUpUser(makerUser);
        _setUpTakerUserAndGrantApprovals(itemOwner, collection);

        OrderStructs.Maker memory makerBid = _createSingleItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: withMerkleTreeCriteria ? 2 : 1,
            collectionType: CollectionType.ERC721,
            orderNonce: 0,
            collection: collection,
            currency: address(weth),
            signer: makerUser,
            price: price,
            itemId: 0
        });

        if (withMerkleTreeCriteria) {
            (bytes32 merkleRoot, bytes32[] memory proof) = _getMerkleRootAndProof({itemIdInMerkleTree: itemId});

            makerBid.additionalParameters = abi.encode(merkleRoot, defaultTransferCooldownPeriod);
            // Add the proof to the taker additional parameters and generate the Taker struct
            takerAdditionalParameters = _addProofToTakerAdditionalParameters(takerAdditionalParameters, proof);
        } else {
            // Encode the transfer cooldown period
            makerBid.additionalParameters = abi.encode(defaultTransferCooldownPeriod);
        }

        // Sign order
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);
        OrderStructs.Taker memory takerAsk = OrderStructs.Taker(takerUser, takerAdditionalParameters);

        // Verify validity of maker bid order
        _assertOrderIsValid(makerBid, withMerkleTreeCriteria);
        _assertValidMakerOrder(makerBid, signature);

        // Execute taker ask transaction
        vm.prank(itemOwner);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Maker user has received the asset
        assertEq(IERC721(collection).ownerOf(itemId), makerUser);
    }

    function _testRevertsIfItemIsFlagged(bool withMerkleTreeCriteria) internal {
        (
            uint256 forkedBlockNumber,
            ,
            address collection,
            uint256 flaggedItemId,
            address itemOwner,
            bytes memory takerAdditionalParameters
        ) = _returnFlaggedItemDataFromReservoir();

        _setUpForkAtBlockNumber(forkedBlockNumber);
        _setUpUser(makerUser);
        _setUpTakerUserAndGrantApprovals(itemOwner, collection);

        OrderStructs.Maker memory makerBid = _createSingleItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: withMerkleTreeCriteria ? 2 : 1,
            collectionType: CollectionType.ERC721,
            orderNonce: 0,
            collection: collection,
            currency: address(weth),
            signer: makerUser,
            price: price,
            itemId: 0
        });

        if (withMerkleTreeCriteria) {
            (bytes32 merkleRoot, bytes32[] memory proof) = _getMerkleRootAndProof({itemIdInMerkleTree: flaggedItemId});

            // Encode with the merkle root with the transfer cooldown period
            makerBid.additionalParameters = abi.encode(merkleRoot, defaultTransferCooldownPeriod);
            // Add the merkle proof to the taker additional parameters and generate the Taker struct
            takerAdditionalParameters = _addProofToTakerAdditionalParameters(takerAdditionalParameters, proof);
        } else {
            // Encode the transfer cooldown period
            makerBid.additionalParameters = abi.encode(defaultTransferCooldownPeriod);
        }

        // Sign order and prepare taker ask
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);
        OrderStructs.Taker memory takerAsk = OrderStructs.Taker(takerUser, takerAdditionalParameters);

        // Verify validity of maker bid order
        _assertOrderIsValid(makerBid, withMerkleTreeCriteria);
        _assertValidMakerOrder(makerBid, signature);

        vm.prank(itemOwner);
        vm.expectRevert(abi.encodeWithSelector(ItemIdFlagged.selector, collection, flaggedItemId));
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function _testRevertsIfLastTransferTimeIsZero(bool withMerkleTreeCriteria) internal {
        (
            uint256 forkedBlockNumber,
            ,
            address collection,
            uint256 itemId,
            address itemOwner,
            bytes memory takerAdditionalParameters
        ) = _returnInvalidNonFlaggedItemDataFromReservoir();

        _setUpForkAtBlockNumber(forkedBlockNumber);
        _setUpUser(makerUser);
        _setUpTakerUserAndGrantApprovals(itemOwner, collection);

        OrderStructs.Maker memory makerBid = _createSingleItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: withMerkleTreeCriteria ? 2 : 1,
            collectionType: CollectionType.ERC721,
            orderNonce: 0,
            collection: collection,
            currency: address(weth),
            signer: makerUser,
            price: price,
            itemId: 0 // Not used
        });

        if (withMerkleTreeCriteria) {
            (bytes32 merkleRoot, bytes32[] memory proof) = _getMerkleRootAndProof({itemIdInMerkleTree: itemId});

            makerBid.additionalParameters = abi.encode(merkleRoot, defaultTransferCooldownPeriod);
            // Add the proof to the taker additional parameters and generate the Taker struct
            takerAdditionalParameters = _addProofToTakerAdditionalParameters(takerAdditionalParameters, proof);
        } else {
            // Encode the transfer cooldown period
            makerBid.additionalParameters = abi.encode(defaultTransferCooldownPeriod);
        }

        // Sign order and prepare taker ask
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);
        OrderStructs.Taker memory takerAsk = OrderStructs.Taker(itemOwner, takerAdditionalParameters);

        _assertOrderIsValid(makerBid, withMerkleTreeCriteria);
        _assertValidMakerOrder(makerBid, signature);

        // Execute taker ask transaction
        vm.prank(itemOwner);
        vm.expectRevert(LastTransferTimeInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function _testRevertsIfTransferWithinCooldownPeriodOrTransferCooldownPeriodTooHigh(
        bool withMerkleTreeCriteria
    ) internal {
        (
            uint256 forkedBlockNumber,
            ,
            address collection,
            uint256 itemId,
            address itemOwner,
            uint256 lastTransferTime,
            bytes memory takerAdditionalParameters
        ) = _returnValidNonFlaggedItemDataFromReservoir();

        _setUpForkAtBlockNumber(forkedBlockNumber);
        _setUpUser(makerUser);
        _setUpTakerUserAndGrantApprovals(itemOwner, collection);

        OrderStructs.Maker memory makerBid = _createSingleItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: withMerkleTreeCriteria ? 2 : 1,
            collectionType: CollectionType.ERC721,
            orderNonce: 0,
            collection: collection,
            currency: address(weth),
            signer: makerUser,
            price: price,
            itemId: 0 // Not used
        });

        //
        // 1. Reverts if transfer too recent
        //

        // Maker user specifies the cooldown period for transfer
        uint256 transferCooldownPeriod = block.timestamp - lastTransferTime + 1;

        // Initialize merkle root since it is reused multiple times in this test
        bytes32 merkleRoot;

        if (withMerkleTreeCriteria) {
            bytes32[] memory proof;
            (merkleRoot, proof) = _getMerkleRootAndProof({itemIdInMerkleTree: itemId});

            makerBid.additionalParameters = abi.encode(merkleRoot, transferCooldownPeriod);
            // Add the proof to the taker additional parameters and generate the Taker struct
            takerAdditionalParameters = _addProofToTakerAdditionalParameters(takerAdditionalParameters, proof);
        } else {
            makerBid.additionalParameters = abi.encode(transferCooldownPeriod);
        }

        // Sign order and prepare taker ask
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);
        OrderStructs.Taker memory takerAsk = OrderStructs.Taker(itemOwner, takerAdditionalParameters);

        // It fails because transferCooldownPeriod > MAXIMUM_TRANSFER_COOLDOWN_PERIOD
        _assertOrderIsInvalid(makerBid, withMerkleTreeCriteria);
        _assertMakerOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(abi.encodeWithSelector(ItemTransferredTooRecently.selector, collection, itemId));
        vm.prank(itemOwner);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        //
        // 2. Reverts if transfer cooldown period is too high
        //

        // Maker user specifies the cooldown period for transfer as limit + 1
        transferCooldownPeriod = MAXIMUM_TRANSFER_COOLDOWN_PERIOD + 1;

        if (withMerkleTreeCriteria) {
            makerBid.additionalParameters = abi.encode(merkleRoot, transferCooldownPeriod);
        } else {
            makerBid.additionalParameters = abi.encode(transferCooldownPeriod);
        }

        signature = _signMakerOrder(makerBid, makerUserPK);

        _assertOrderIsInvalid(makerBid, withMerkleTreeCriteria);
        _assertMakerOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(TransferCooldownPeriodTooHigh.selector);
        vm.prank(itemOwner);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function _testRevertsIfSignatureExpires(bool withMerkleTreeCriteria) public {
        (
            uint256 forkedBlockNumber,
            uint256 timestamp,
            address collection,
            uint256 itemId,
            address itemOwner,
            ,
            bytes memory takerAdditionalParameters
        ) = _returnValidNonFlaggedItemDataFromReservoir();

        _setUpForkAtBlockNumber(forkedBlockNumber);
        _setUpUser(makerUser);
        _setUpTakerUserAndGrantApprovals(itemOwner, collection);

        OrderStructs.Maker memory makerBid = _createSingleItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: withMerkleTreeCriteria ? 2 : 1,
            collectionType: CollectionType.ERC721,
            orderNonce: 0,
            collection: collection,
            currency: address(weth),
            signer: makerUser,
            price: price,
            itemId: 0 // Not used
        });

        // End time is increased to prevent OutsideOfTimeRange() after vm.warp
        makerBid.endTime = timestamp + SIGNATURE_VALIDITY_PERIOD + 1;

        if (withMerkleTreeCriteria) {
            (bytes32 merkleRoot, bytes32[] memory proof) = _getMerkleRootAndProof({itemIdInMerkleTree: itemId});

            makerBid.additionalParameters = abi.encode(merkleRoot, defaultTransferCooldownPeriod);
            // Add the proof to the taker additional parameters and generate the Taker struct
            takerAdditionalParameters = _addProofToTakerAdditionalParameters(takerAdditionalParameters, proof);
        } else {
            // Encode the transfer cooldown period
            makerBid.additionalParameters = abi.encode(defaultTransferCooldownPeriod);
        }

        // Sign order and prepare taker ask
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);
        OrderStructs.Taker memory takerAsk = OrderStructs.Taker(itemOwner, takerAdditionalParameters);

        _assertOrderIsValid(makerBid, withMerkleTreeCriteria);
        _assertValidMakerOrder(makerBid, signature);

        // Time travel
        vm.warp(timestamp + SIGNATURE_VALIDITY_PERIOD + 1);

        vm.expectRevert(SignatureExpired.selector);
        vm.prank(itemOwner);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function _testRevertsIfCollectionTypeIsNotERC721(bool withMerkleTreeCriteria) public {
        (
            uint256 forkedBlockNumber,
            uint256 timestamp,
            address collection,
            uint256 itemId,
            address itemOwner,
            ,
            bytes memory takerAdditionalParameters
        ) = _returnValidNonFlaggedItemDataFromReservoir();

        _setUpForkAtBlockNumber(forkedBlockNumber);
        _setUpUser(makerUser);
        _setUpTakerUserAndGrantApprovals(itemOwner, collection);

        OrderStructs.Maker memory makerBid = _createSingleItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: withMerkleTreeCriteria ? 2 : 1,
            collectionType: CollectionType.ERC1155,
            orderNonce: 0,
            collection: collection,
            currency: address(weth),
            signer: makerUser,
            price: price,
            itemId: 0 // Not used
        });

        // End time is increased to prevent OutsideOfTimeRange() after vm.warp
        makerBid.endTime = timestamp + SIGNATURE_VALIDITY_PERIOD + 1;

        if (withMerkleTreeCriteria) {
            (bytes32 merkleRoot, bytes32[] memory proof) = _getMerkleRootAndProof({itemIdInMerkleTree: itemId});

            makerBid.additionalParameters = abi.encode(merkleRoot, defaultTransferCooldownPeriod);
            // Add the proof to the taker additional parameters and generate the Taker struct
            takerAdditionalParameters = _addProofToTakerAdditionalParameters(takerAdditionalParameters, proof);
        } else {
            // Encode the transfer cooldown period
            makerBid.additionalParameters = abi.encode(defaultTransferCooldownPeriod);
        }

        // Sign order and prepare taker ask
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);
        OrderStructs.Taker memory takerAsk = OrderStructs.Taker(itemOwner, takerAdditionalParameters);

        _assertOrderIsInvalid(makerBid, withMerkleTreeCriteria);
        _assertMakerOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(OrderInvalid.selector);
        vm.prank(itemOwner);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function _testAmountsInvalid(bool withMerkleTreeCriteria) internal {
        (
            uint256 forkedBlockNumber,
            ,
            address collection,
            uint256 itemId,
            address itemOwner,
            ,
            bytes memory takerAdditionalParameters
        ) = _returnValidNonFlaggedItemDataFromReservoir();

        _setUpForkAtBlockNumber(forkedBlockNumber);
        _setUpUser(makerUser);
        _setUpTakerUserAndGrantApprovals(itemOwner, collection);

        OrderStructs.Maker memory makerBid = _createSingleItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: withMerkleTreeCriteria ? 2 : 1,
            collectionType: CollectionType.ERC721,
            orderNonce: 0,
            collection: collection,
            currency: address(weth),
            signer: makerUser,
            price: price,
            itemId: 0 // Not used
        });

        // 1. Adjust amounts to array length = 2
        uint256[] memory amounts = new uint256[](2);
        makerBid.amounts = amounts;

        if (withMerkleTreeCriteria) {
            (bytes32 merkleRoot, bytes32[] memory proof) = _getMerkleRootAndProof({itemIdInMerkleTree: itemId});

            makerBid.additionalParameters = abi.encode(merkleRoot, defaultTransferCooldownPeriod);
            // Add the proof to the taker additional parameters and generate the Taker struct
            takerAdditionalParameters = _addProofToTakerAdditionalParameters(takerAdditionalParameters, proof);
        } else {
            // Encode the transfer cooldown period
            makerBid.additionalParameters = abi.encode(defaultTransferCooldownPeriod);
        }

        // Sign order and prepare taker ask
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);
        OrderStructs.Taker memory takerAsk = OrderStructs.Taker(itemOwner, takerAdditionalParameters);

        _assertOrderIsInvalid(makerBid, withMerkleTreeCriteria);
        _assertMakerOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(OrderInvalid.selector);
        vm.prank(itemOwner);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // 2. Adjust amounts to array length = 0
        amounts = new uint256[](0);
        makerBid.amounts = amounts;
        signature = _signMakerOrder(makerBid, makerUserPK);

        _assertOrderIsInvalid(makerBid, withMerkleTreeCriteria);
        _assertMakerOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(OrderInvalid.selector);
        vm.prank(itemOwner);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // 3. Adjust amounts to array length = 1 but amount is 0
        amounts = new uint256[](1);
        amounts[0] = 0;
        makerBid.amounts = amounts;
        signature = _signMakerOrder(makerBid, makerUserPK);

        _assertOrderIsInvalid(makerBid, withMerkleTreeCriteria);
        _assertMakerOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(AmountInvalid.selector);
        vm.prank(itemOwner);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // 4. Adjust amounts to array length = 1 but amount is 2
        amounts[0] = 2;
        makerBid.amounts = amounts;
        signature = _signMakerOrder(makerBid, makerUserPK);

        _assertOrderIsInvalid(makerBid, withMerkleTreeCriteria);
        _assertMakerOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(AmountInvalid.selector);
        vm.prank(itemOwner);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function _testCollectionOrderRevertsIfItemIdDiffers(bool withMerkleTreeCriteria, uint256 itemId) internal {
        // 420 is the itemId that is from the Reservoir's data
        vm.assume(itemId != 420 && itemId <= 20000);

        // @dev Trying to sell an itemId that is not the one in the Reservoir's data
        //      will generate an invalid message id.
        (
            uint256 forkedBlockNumber,
            ,
            address collection,
            ,
            address itemOwner,
            ,
            bytes memory takerAdditionalParameters
        ) = _returnValidNonFlaggedItemDataFromReservoir();

        takerAdditionalParameters = _corruptTakerAdditionalParametersByChangingItemId(
            takerAdditionalParameters,
            itemId
        );

        _setUpForkAtBlockNumber(forkedBlockNumber);
        _setUpUser(makerUser);
        _setUpTakerUserAndGrantApprovals(itemOwner, collection);

        OrderStructs.Maker memory makerBid = _createSingleItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: withMerkleTreeCriteria ? 2 : 1,
            collectionType: CollectionType.ERC721,
            orderNonce: 0,
            collection: collection,
            currency: address(weth),
            signer: makerUser,
            price: price,
            itemId: 0 // Not used
        });

        if (withMerkleTreeCriteria) {
            (bytes32 merkleRoot, bytes32[] memory proof) = _getMerkleRootAndProof({itemIdInMerkleTree: itemId});

            makerBid.additionalParameters = abi.encode(merkleRoot, defaultTransferCooldownPeriod);
            // Add the proof to the taker additional parameters and generate the Taker struct
            takerAdditionalParameters = _addProofToTakerAdditionalParameters(takerAdditionalParameters, proof);
        } else {
            // Encode the transfer cooldown period
            makerBid.additionalParameters = abi.encode(defaultTransferCooldownPeriod);
        }

        // Sign order and prepare taker ask
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);
        OrderStructs.Taker memory takerAsk = OrderStructs.Taker(itemOwner, takerAdditionalParameters);

        // Verify validity of maker bid order
        _assertOrderIsValid(makerBid, withMerkleTreeCriteria);
        _assertValidMakerOrder(makerBid, signature);

        vm.expectRevert(MessageIdInvalid.selector);
        vm.prank(itemOwner);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function _testAdditionalParametersLengthInvalid(bool withMerkleTreeCriteria) internal {
        _setUp();
        _setUpNewStrategies();

        OrderStructs.Maker memory makerBid = _createSingleItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: withMerkleTreeCriteria ? 2 : 1,
            collectionType: CollectionType.ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            price: price,
            itemId: 0 // Not used
        });

        // Sign order and prepare taker ask
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        _assertOrderIsInvalid(makerBid, withMerkleTreeCriteria);
        _assertMakerOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);
    }

    function _setUpForkAtBlockNumber(uint256 blockNumber) private {
        vm.createSelectFork(vm.rpcUrl("mainnet"), blockNumber);
        _setUp();
        _setUpNewStrategies();
    }

    function _setUpTakerUserAndGrantApprovals(address user, address collection) private {
        _setUpUser(user);
        vm.prank(user);
        IERC721(collection).setApprovalForAll(address(transferManager), true);
    }

    function _returnFlaggedItemDataFromReservoir()
        private
        pure
        returns (
            uint256 forkedBlockNumber,
            uint256 timestamp,
            address collection,
            uint256 itemId,
            address itemOwner,
            bytes memory takerAdditionalParameters
        )
    {
        /**
         * @dev The below is the response from Reservoir's API
         *   {
         *       "token": "0x60e4d786628fea6478f785a6d7e704777c86a7c6:14412",
         *       "isFlagged": true,
         *       "lastTransferTime": 1675157279,
         *       "message":
         *              {
         *                "id": "0xf028a527cd00aeef0191c213ca8f6f1a5649efb6b83db3e8451fda701933e70e",
         *                "payload": "0x00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000063d8df1f",
         *                "timestamp": 1675226327,
         *                "signature": "0xb2f5a86289bab990d1b7bed6bc8b373e0a01bff11cbcc4f1d3d9e697fae98768226969527ab7efa61631b86bd441e40a3a89a3c2bbbda271d607bd8cfe3335211c"
         *              }
         *   }
         */

        // @dev The signature timestamp was exactly the same as the one from block 16_531_634
        forkedBlockNumber = 16_531_634;
        timestamp = 1_675_226_327;
        itemId = 14_412;
        collection = 0x60E4d786628Fea6478F785A6d7e704777c86a7c6;
        itemOwner = 0xF5b9d00f6184954D6e725215D9Cab5F5698e8Bb3; // This address owns the flagged itemId

        takerAdditionalParameters = abi.encode(
            bytes32(0xf028a527cd00aeef0191c213ca8f6f1a5649efb6b83db3e8451fda701933e70e),
            hex"00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000063d8df1f",
            uint256(timestamp),
            hex"b2f5a86289bab990d1b7bed6bc8b373e0a01bff11cbcc4f1d3d9e697fae98768226969527ab7efa61631b86bd441e40a3a89a3c2bbbda271d607bd8cfe3335211c",
            uint256(itemId)
        );
    }

    function _returnInvalidNonFlaggedItemDataFromReservoir()
        private
        pure
        returns (
            uint256 forkedBlockNumber,
            uint256 timestamp,
            address collection,
            uint256 itemId,
            address itemOwner,
            bytes memory takerAdditionalParameters
        )
    {
        /**
         * @dev The below is the invalid response from Reservoir's API that is still properly signed.
         *   {
         *       "token": "0x60e4d786628fea6478f785a6d7e704777c86a7c6:420",
         *       "isFlagged": false,
         *       "lastTransferTime": 0,
         *       "message":
         *              {
         *                "id": "0xdfe46268693892a9f04f448e598fdf46e54128885f9f152fabb92b3a1628623e",
         *                "payload": "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
         *                "timestamp": 1675386659,
         *                "signature": "0x03e0d8c2e100b8717deb7c9cefbabbac84d78908dc79f352de9fc328bb7ffa0c325037a7fa638d344c02dc077cd8f798dcc666765c2eaeccfb4fbde71c36325f1b"
         *              }
         *   }
         */

        forkedBlockNumber = 16_544_902;
        timestamp = 1_675_386_659;
        itemId = 420;
        collection = 0x60E4d786628Fea6478F785A6d7e704777c86a7c6;
        itemOwner = 0xE052113bd7D7700d623414a0a4585BCaE754E9d5; // This address owns the itemId

        takerAdditionalParameters = abi.encode(
            bytes32(0xdfe46268693892a9f04f448e598fdf46e54128885f9f152fabb92b3a1628623e),
            hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            uint256(timestamp),
            hex"03e0d8c2e100b8717deb7c9cefbabbac84d78908dc79f352de9fc328bb7ffa0c325037a7fa638d344c02dc077cd8f798dcc666765c2eaeccfb4fbde71c36325f1b",
            uint256(itemId)
        );
    }

    function _returnValidNonFlaggedItemDataFromReservoir()
        private
        pure
        returns (
            uint256 forkedBlockNumber,
            uint256 timestamp,
            address collection,
            uint256 itemId,
            address itemOwner,
            uint256 lastTransferTime,
            bytes memory takerAdditionalParameters
        )
    {
        /**
         * @dev The below is the response from Reservoir's API
         *   {
         *       "token": "0x60e4d786628fea6478f785a6d7e704777c86a7c6:420",
         *       "isFlagged": false,
         *       "lastTransferTime": 1652309738,
         *       "message":
         *              {
         *                "id": "0xdfe46268693892a9f04f448e598fdf46e54128885f9f152fabb92b3a1628623e",
         *                "payload": "0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000627c3eea",
         *                "timestamp": 1675386659,
         *                "signature": "0xf3eeeef0bc09cc510fb8edde0196fa4208e868232649a4d0fd565f00aed176a608899f2609aaada31457388ced8c16c84f52a9d132d817bb3db7d61ab96d8eb61b"
         *              }
         *   }
         */

        forkedBlockNumber = 16_544_902;
        timestamp = 1_675_386_659;
        itemId = 420;
        collection = 0x60E4d786628Fea6478F785A6d7e704777c86a7c6;
        itemOwner = 0xE052113bd7D7700d623414a0a4585BCaE754E9d5; // This address owns the itemId
        lastTransferTime = 1_652_309_738;

        takerAdditionalParameters = abi.encode(
            bytes32(0xdfe46268693892a9f04f448e598fdf46e54128885f9f152fabb92b3a1628623e),
            hex"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000627c3eea",
            uint256(timestamp),
            hex"f3eeeef0bc09cc510fb8edde0196fa4208e868232649a4d0fd565f00aed176a608899f2609aaada31457388ced8c16c84f52a9d132d817bb3db7d61ab96d8eb61b",
            uint256(itemId)
        );
    }

    function _setUpNewStrategies() private asPrankedUser(_owner) {
        strategyReservoirCollectionOffer = new StrategyReservoirCollectionOffer();
        _addStrategy(address(strategyReservoirCollectionOffer), selectorNoProof, true);
        _addStrategy(address(strategyReservoirCollectionOffer), selectorWithProof, true);
    }

    function _assertOrderIsValid(OrderStructs.Maker memory makerBid, bool withMerkleTreeCriteria) private {
        (bool orderIsValid, bytes4 errorSelector) = strategyReservoirCollectionOffer.isMakerOrderValid(
            makerBid,
            withMerkleTreeCriteria ? selectorWithProof : selectorNoProof
        );
        assertTrue(orderIsValid);
        assertEq(errorSelector, _EMPTY_BYTES4);
    }

    function _assertOrderIsInvalid(OrderStructs.Maker memory makerBid, bool withMerkleTreeCriteria) private {
        (bool orderIsValid, bytes4 errorSelector) = strategyReservoirCollectionOffer.isMakerOrderValid(
            makerBid,
            withMerkleTreeCriteria ? selectorWithProof : selectorNoProof
        );

        assertFalse(orderIsValid);
        assertEq(errorSelector, OrderInvalid.selector);
    }

    function _getMerkleRootAndProof(
        uint256 itemIdInMerkleTree
    ) private returns (bytes32 merkleRoot, bytes32[] memory proof) {
        uint256 numberOfItemsInMerkleTree = (itemIdInMerkleTree >= 1000) ? itemIdInMerkleTree + 50 : 1000;

        Merkle m = new Merkle();

        bytes32[] memory merkleTreeIds = new bytes32[](numberOfItemsInMerkleTree);
        for (uint256 i; i < numberOfItemsInMerkleTree; i++) {
            merkleTreeIds[i] = keccak256(abi.encodePacked(i));
        }

        merkleRoot = m.getRoot(merkleTreeIds);
        proof = m.getProof(merkleTreeIds, itemIdInMerkleTree);

        assertTrue(m.verifyProof(merkleRoot, proof, merkleTreeIds[itemIdInMerkleTree]));
    }

    function _addProofToTakerAdditionalParameters(
        bytes memory takerAdditionalParameters,
        bytes32[] memory proof
    ) private pure returns (bytes memory adjustedTakerAdditionalParameters) {
        (bytes32 messageId, bytes memory payload, uint256 timestamp, bytes memory signature, uint256 itemId) = abi
            .decode(takerAdditionalParameters, (bytes32, bytes, uint256, bytes, uint256));

        adjustedTakerAdditionalParameters = abi.encode(messageId, payload, timestamp, signature, itemId, proof);
    }

    function _corruptTakerAdditionalParametersByChangingItemId(
        bytes memory takerAdditionalParameters,
        uint256 newItemId
    ) private pure returns (bytes memory corruptedTakerAdditionalParameters) {
        (bytes32 messageId, bytes memory payload, uint256 timestamp, bytes memory signature, ) = abi.decode(
            takerAdditionalParameters,
            (bytes32, bytes, uint256, bytes, uint256)
        );

        corruptedTakerAdditionalParameters = abi.encode(messageId, payload, timestamp, signature, newItemId);
    }
}
