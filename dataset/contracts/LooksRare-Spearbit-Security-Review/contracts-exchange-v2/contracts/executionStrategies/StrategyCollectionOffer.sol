// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "../libraries/OrderStructs.sol";

// OpenZeppelin's library for verifying Merkle proofs
import {MerkleProofMemory} from "../libraries/OpenZeppelin/MerkleProofMemory.sol";

// Shared errors
import {OrderInvalid, WrongFunctionSelector, WrongMerkleProof} from "../interfaces/SharedErrors.sol";

// Base strategy contracts
import {BaseStrategy} from "./BaseStrategy.sol";

/**
 * @title StrategyCollectionOffer
 * @notice This contract offers execution strategies for users to create maker bid offers for items in a collection.
 *         There are two available functions:
 *         1. executeCollectionStrategyWithTakerAsk --> it applies to all item ids in a collection
 *         2. executeCollectionStrategyWithTakerAskWithProof --> it is same except that it allows adding merkle proof criteria.
 * @dev Use cases can include trait-based offers or rarity score offers.
 * @author LooksRare protocol team (ðŸ‘€,ðŸ’Ž)
 */
contract StrategyCollectionOffer is BaseStrategy {
    /**
     * @notice This function validates the order under the context of the chosen strategy and return the fulfillable items/amounts/price/nonce invalidation status.
     *         This strategy executes a collection offer against a taker ask order without the need of merkle proofs.
     * @param takerAsk Taker ask struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid Maker bid struct (contains the maker bid-specific parameters for the execution of the transaction)
     */
    function executeCollectionStrategyWithTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    )
        external
        pure
        returns (uint256 price, uint256[] calldata itemIds, uint256[] calldata amounts, bool isNonceInvalidated)
    {
        price = makerBid.maxPrice;
        itemIds = takerAsk.itemIds;
        amounts = makerBid.amounts;
        isNonceInvalidated = true;

        // A collection order can only be executable for 1 itemId but quantity to fill can vary
        if (itemIds.length != 1 || amounts.length != 1 || price != takerAsk.minPrice) {
            revert OrderInvalid();
        }

        uint256 makerAmount = amounts[0];

        if (makerAmount != takerAsk.amounts[0]) {
            revert OrderInvalid();
        }

        if (makerAmount != 1) {
            if (makerAmount == 0) {
                revert OrderInvalid();
            }
            if (makerBid.assetType == 0) {
                revert OrderInvalid();
            }
        }
    }

    /**
     * @notice This function validates the order under the context of the chosen strategy and return the fulfillable items/amounts/price/nonce invalidation status.
     *         This strategy executes a collection offer against a taker ask order with the need of merkle proofs.
     * @param takerAsk Taker ask struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid Maker bid struct (contains the maker bid-specific parameters for the execution of the transaction)
     * @dev The transaction reverts if there is the maker does not include a merkle root in the additionalParameters.
     */
    function executeCollectionStrategyWithTakerAskWithProof(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    )
        external
        pure
        returns (uint256 price, uint256[] calldata itemIds, uint256[] calldata amounts, bool isNonceInvalidated)
    {
        price = makerBid.maxPrice;
        itemIds = takerAsk.itemIds;
        amounts = makerBid.amounts;
        isNonceInvalidated = true;

        // A collection order can only be executable for 1 itemId but the actual quantity to fill can vary
        if (itemIds.length != 1 || amounts.length != 1 || price != takerAsk.minPrice) {
            revert OrderInvalid();
        }

        uint256 makerAmount = amounts[0];

        if (makerAmount != takerAsk.amounts[0]) {
            revert OrderInvalid();
        }

        if (makerAmount != 1) {
            if (makerAmount == 0) {
                revert OrderInvalid();
            }
            if (makerBid.assetType == 0) {
                revert OrderInvalid();
            }
        }

        bytes32 root = abi.decode(makerBid.additionalParameters, (bytes32));
        bytes32[] memory proof = abi.decode(takerAsk.additionalParameters, (bytes32[]));
        bytes32 node = keccak256(abi.encodePacked(takerAsk.itemIds[0]));

        // Verify the merkle root for the given merkle proof
        if (!MerkleProofMemory.verify(proof, root, node)) {
            revert WrongMerkleProof();
        }
    }

    /**
     * @notice This function validates *only the maker* order under the context of the chosen strategy.
     *         It does not revert if the maker order is invalid. Instead it returns false and the error's 4 bytes selector.
     * @param makerBid Maker bid struct (contains the maker bid-specific parameters for the execution of the transaction)
     * @param functionSelector Function selector for the strategy
     * @return isValid Whether the maker struct is valid
     * @return errorSelector If isValid is false, it returns the error's 4 bytes selector
     */
    function isMakerBidValid(
        OrderStructs.MakerBid calldata makerBid,
        bytes4 functionSelector
    ) external pure returns (bool isValid, bytes4 errorSelector) {
        if (
            functionSelector != StrategyCollectionOffer.executeCollectionStrategyWithTakerAskWithProof.selector &&
            functionSelector != StrategyCollectionOffer.executeCollectionStrategyWithTakerAsk.selector
        ) {
            return (isValid, WrongFunctionSelector.selector);
        }

        if (makerBid.amounts.length != 1) {
            return (isValid, OrderInvalid.selector);
        }

        if (makerBid.amounts[0] != 1) {
            if (makerBid.amounts[0] == 0) {
                return (isValid, OrderInvalid.selector);
            }
            if (makerBid.assetType == 0) {
                return (isValid, OrderInvalid.selector);
            }
        }

        // If no root is provided or wrong length, it should be invalid.
        // @dev It doesn't mean the merkle root is valid against a specific itemId that exists in the collection.
        if (
            functionSelector == StrategyCollectionOffer.executeCollectionStrategyWithTakerAskWithProof.selector &&
            makerBid.additionalParameters.length != 32
        ) {
            return (isValid, OrderInvalid.selector);
        }

        isValid = true;
    }
}
