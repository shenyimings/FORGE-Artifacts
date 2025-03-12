// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// LooksRare unopinionated libraries
import {SignatureCheckerMemory} from "@looksrare/contracts-libs/contracts/SignatureCheckerMemory.sol";

// Libraries
import {OrderStructs} from "../../libraries/OrderStructs.sol";

// OpenZeppelin's library for verifying Merkle proofs
import {MerkleProofMemory} from "../../libraries/OpenZeppelin/MerkleProofMemory.sol";

// Enums
import {CollectionType} from "../../enums/CollectionType.sol";
import {QuoteType} from "../../enums/QuoteType.sol";

// Errors
import {FunctionSelectorInvalid, MerkleProofInvalid, OrderInvalid, QuoteTypeInvalid} from "../../errors/SharedErrors.sol";
import {ItemIdFlagged, ItemTransferredTooRecently, LastTransferTimeInvalid, MessageIdInvalid, SignatureExpired, TransferCooldownPeriodTooHigh} from "../../errors/ReservoirErrors.sol";

// Base strategy contracts
import {BaseStrategy, IStrategy} from "../BaseStrategy.sol";

/**
 * @title StrategyReservoirCollectionOffer
 * @notice This contract offers execution strategies for users, which allow them
 *         to create advanced maker bid offers for items in a collection.
 *         The taker must provide the proof that (1) the itemId is not flagged
 *         and (2) the item has not been transferred after a specific time.
 *         This strategy is only available for ERC721 tokens (collectionType = 0).
 *         There are two available functions:
 *         1. executeCollectionStrategyWithTakerAsk --> it applies to all itemIds in a collection
 *         2. executeCollectionStrategyWithTakerAskWithProof --> it allows adding merkle proof criteria.
 *         The bidder can only bid on 1 token id at a time and the amount must be 1.
 * @author LooksRare protocol team (ðŸ‘€,ðŸ’Ž)
 */
contract StrategyReservoirCollectionOffer is BaseStrategy {
    /**
     * @notice Reservoir's oracle address.
     */
    address public constant ORACLE_ADDRESS = 0xAeB1D03929bF87F69888f381e73FBf75753d75AF;

    /**
     * @notice Default validity period of a signature.
     * @dev For this strategy, clients must request users to send the transaction
     *      with a very high gas price to make sure it is included while the signature is valid.
     */
    uint256 public constant SIGNATURE_VALIDITY_PERIOD = 90 seconds;

    /**
     * @notice Maximum cooldown period.
     */
    uint256 public constant MAXIMUM_TRANSFER_COOLDOWN_PERIOD = 24 hours;

    /**
     * @notice Message's typehash constant.
     * @dev It is used to compute the hash of the message using the (message) id, the payload, and the timestamp.
     */
    bytes32 internal constant _MESSAGE_TYPEHASH = keccak256("Message(bytes32 id,bytes payload,uint256 timestamp)");

    /**
     * @notice Token's typehash constant.
     * @dev It is used to compute the expected message id and verifies it against the message id signed.
     */
    bytes32 internal constant _TOKEN_TYPEHASH = keccak256("Token(address contract,uint256 tokenId)");

    /**
     * @notice This function validates the order under the context of the chosen strategy and
     *         returns the fulfillable items/amounts/price/nonce invalidation status.
     *         This strategy executes a collection offer against a taker ask order without the need of merkle proofs.
     * @param takerAsk Taker ask struct (taker ask-specific parameters for the execution)
     * @param makerBid Maker bid struct (maker bid-specific parameters for the execution)
     */
    function executeCollectionStrategyWithTakerAsk(
        OrderStructs.Taker calldata takerAsk,
        OrderStructs.Maker calldata makerBid
    )
        external
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] calldata amounts, bool isNonceInvalidated)
    {
        price = makerBid.price;
        amounts = makerBid.amounts;

        // It can be executed only for 1 itemId and only for ERC721
        if (amounts.length != 1 || makerBid.collectionType != CollectionType.ERC721) {
            revert OrderInvalid();
        }

        uint256 offeredItemId = _validateAdditionalParametersAndGetOfferedItemId(
            makerBid.collection,
            makerBid.additionalParameters,
            takerAsk.additionalParameters
        );

        itemIds = new uint256[](1);
        itemIds[0] = offeredItemId;
        isNonceInvalidated = true;
    }

    /**
     * @notice This function validates the order under the context of the chosen strategy
     *         and returns the fulfillable items/amounts/price/nonce invalidation status.
     *         This strategy executes a collection offer against a taker ask order with the need of a merkle proof.
     * @param takerAsk Taker ask struct (taker ask-specific parameters for the execution)
     * @param makerBid Maker bid struct (maker bid-specific parameters for the execution)
     * @dev The transaction reverts if the maker does not include a merkle root in the additionalParameters.
     */
    function executeCollectionStrategyWithTakerAskWithProof(
        OrderStructs.Taker calldata takerAsk,
        OrderStructs.Maker calldata makerBid
    )
        external
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] calldata amounts, bool isNonceInvalidated)
    {
        price = makerBid.price;
        amounts = makerBid.amounts;

        // It can be executed only for 1 itemId and only for ERC721
        if (amounts.length != 1 || makerBid.collectionType != CollectionType.ERC721) {
            revert OrderInvalid();
        }

        uint256 offeredItemId = _validateAdditionalParametersAndGetOfferedItemIdWithProof(
            makerBid.collection,
            makerBid.additionalParameters,
            takerAsk.additionalParameters
        );

        itemIds = new uint256[](1);
        itemIds[0] = offeredItemId;
        isNonceInvalidated = true;
    }

    /**
     * @inheritdoc IStrategy
     */
    function isMakerOrderValid(
        OrderStructs.Maker calldata makerBid,
        bytes4 functionSelector
    ) external pure override returns (bool isValid, bytes4 errorSelector) {
        if (
            functionSelector !=
            StrategyReservoirCollectionOffer.executeCollectionStrategyWithTakerAskWithProof.selector &&
            functionSelector != StrategyReservoirCollectionOffer.executeCollectionStrategyWithTakerAsk.selector
        ) {
            return (isValid, FunctionSelectorInvalid.selector);
        }

        if (makerBid.quoteType != QuoteType.Bid) {
            return (isValid, QuoteTypeInvalid.selector);
        }

        // Amounts length must be 1, amount can only be 1 since only ERC721 can be traded.
        if (
            makerBid.amounts.length != 1 || makerBid.amounts[0] != 1 || makerBid.collectionType != CollectionType.ERC721
        ) {
            return (isValid, OrderInvalid.selector);
        }

        // If transfer cooldown period is not provided or invalid length, it should be invalid.
        if (functionSelector == StrategyReservoirCollectionOffer.executeCollectionStrategyWithTakerAsk.selector) {
            if (makerBid.additionalParameters.length != 32) {
                return (isValid, OrderInvalid.selector);
            } else {
                uint256 transferCooldownPeriod = abi.decode(makerBid.additionalParameters, (uint256));

                // @dev It returns OrderInvalid even if a custom error exists (for order invalidation purposes).
                if (transferCooldownPeriod > MAXIMUM_TRANSFER_COOLDOWN_PERIOD) {
                    return (isValid, OrderInvalid.selector);
                }
            }
        }

        // If root and transfer cooldown period are not provided or invalid length, it should be invalid.
        // @dev It does not mean the merkle root is valid against a specific itemId that exists in the collection.
        if (
            functionSelector == StrategyReservoirCollectionOffer.executeCollectionStrategyWithTakerAskWithProof.selector
        ) {
            if (makerBid.additionalParameters.length != 64) {
                return (isValid, OrderInvalid.selector);
            } else {
                (, uint256 transferCooldownPeriod) = abi.decode(makerBid.additionalParameters, (bytes32, uint256));

                // @dev It returns OrderInvalid even if a custom error exists (for order invalidation purposes).
                if (transferCooldownPeriod > MAXIMUM_TRANSFER_COOLDOWN_PERIOD) {
                    return (isValid, OrderInvalid.selector);
                }
            }
        }

        isValid = true;
    }

    function _validateAdditionalParametersAndGetOfferedItemIdWithProof(
        address collection,
        bytes calldata makerAdditionalParameters,
        bytes calldata takerAdditionalParameters
    ) private view returns (uint256) {
        (
            bytes32 messageId,
            bytes memory payload,
            uint256 timestamp,
            bytes memory signature,
            uint256 offeredItemId,
            bytes32[] memory proof
        ) = abi.decode(takerAdditionalParameters, (bytes32, bytes, uint256, bytes, uint256, bytes32[]));

        (bytes32 root, uint256 transferCooldownPeriod) = abi.decode(makerAdditionalParameters, (bytes32, uint256));

        {
            bytes32 node = keccak256(abi.encodePacked(offeredItemId));

            // Verify the merkle root for the given merkle proof
            if (!MerkleProofMemory.verify(proof, root, node)) {
                revert MerkleProofInvalid();
            }
        }

        _verifyReservoirOracle(
            collection,
            offeredItemId,
            transferCooldownPeriod,
            messageId,
            payload,
            timestamp,
            signature
        );

        return offeredItemId;
    }

    function _validateAdditionalParametersAndGetOfferedItemId(
        address collection,
        bytes calldata makerAdditionalParameters,
        bytes calldata takerAdditionalParameters
    ) private view returns (uint256) {
        (
            bytes32 messageId,
            bytes memory payload,
            uint256 timestamp,
            bytes memory signature,
            uint256 offeredItemId
        ) = abi.decode(takerAdditionalParameters, (bytes32, bytes, uint256, bytes, uint256));

        uint256 transferCooldownPeriod = abi.decode(makerAdditionalParameters, (uint256));

        _verifyReservoirOracle(
            collection,
            offeredItemId,
            transferCooldownPeriod,
            messageId,
            payload,
            timestamp,
            signature
        );

        return offeredItemId;
    }

    function _verifyReservoirOracle(
        address collection,
        uint256 itemId,
        uint256 transferCooldownPeriod,
        bytes32 messageId,
        bytes memory payload,
        uint256 timestamp,
        bytes memory signature
    ) private view {
        // Check the signature timestamp
        if (block.timestamp > timestamp + SIGNATURE_VALIDITY_PERIOD) {
            revert SignatureExpired();
        }

        // Check the message id
        bytes32 expectedMessageId = keccak256(abi.encode(_TOKEN_TYPEHASH, collection, itemId));

        if (expectedMessageId != messageId) {
            revert MessageIdInvalid();
        }

        // Compute the message hash and verify the signature is from the oracle
        _computeMessageHashAndVerify(messageId, payload, timestamp, signature);

        // Fetch the flagged item
        (bool isFlagged, uint256 lastTransferTime) = abi.decode(payload, (bool, uint256));

        // Check if item is flagged
        if (isFlagged) {
            revert ItemIdFlagged(collection, itemId);
        }

        // Check if message was signed with data invalid
        if (lastTransferTime == 0) {
            revert LastTransferTimeInvalid();
        }

        // Check if item was transferred too recently or transfer outside of the cooldown period
        if (block.timestamp < lastTransferTime + transferCooldownPeriod) {
            revert ItemTransferredTooRecently(collection, itemId);
        }

        if (transferCooldownPeriod > MAXIMUM_TRANSFER_COOLDOWN_PERIOD) {
            revert TransferCooldownPeriodTooHigh();
        }
    }

    function _computeMessageHashAndVerify(
        bytes32 id,
        bytes memory payload,
        uint256 timestamp,
        bytes memory signature
    ) private view {
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encode(_MESSAGE_TYPEHASH, id, keccak256(payload), timestamp))
            )
        );

        SignatureCheckerMemory.verify(messageHash, ORACLE_ADDRESS, signature);
    }
}
