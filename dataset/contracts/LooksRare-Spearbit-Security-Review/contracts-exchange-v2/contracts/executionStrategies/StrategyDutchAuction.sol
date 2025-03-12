// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "../libraries/OrderStructs.sol";

// Shared errors
import {BidTooLow, OrderInvalid, WrongFunctionSelector} from "../interfaces/SharedErrors.sol";

// Base strategy contracts
import {BaseStrategy} from "./BaseStrategy.sol";

/**
 * @title StrategyDutchAuction
 * @notice This contract offers a single execution strategy for users to create Dutch auctions.
 * @author LooksRare protocol team (ðŸ‘€,ðŸ’Ž)
 */
contract StrategyDutchAuction is BaseStrategy {
    /**
     * @notice This function validates the order under the context of the chosen strategy and return the fulfillable items/amounts/price/nonce invalidation status.
     *         The execution price set by the seller decreases linearly within the defined period.
     * @param takerBid Taker bid struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerAsk Maker ask struct (contains the maker bid-specific parameters for the execution of the transaction)
     * @dev The client has to provide the seller's desired initial start price as the additionalParameters.
     */
    function executeStrategyWithTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk
    )
        external
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated)
    {
        uint256 itemIdsLength = makerAsk.itemIds.length;

        if (itemIdsLength == 0 || itemIdsLength != makerAsk.amounts.length) {
            revert OrderInvalid();
        }

        for (uint256 i; i < itemIdsLength; ) {
            uint256 amount = makerAsk.amounts[i];

            if (amount != 1) {
                if (amount == 0) {
                    revert OrderInvalid();
                }
                if (makerAsk.assetType == 0) {
                    revert OrderInvalid();
                }
            }

            if (makerAsk.itemIds[i] != takerBid.itemIds[i] || amount != takerBid.amounts[i]) {
                revert OrderInvalid();
            }

            unchecked {
                ++i;
            }
        }

        uint256 startPrice = abi.decode(makerAsk.additionalParameters, (uint256));

        if (startPrice < makerAsk.minPrice) {
            revert OrderInvalid();
        }

        uint256 duration = makerAsk.endTime - makerAsk.startTime;
        uint256 decayPerSecond = (startPrice - makerAsk.minPrice) / duration;

        uint256 elapsedTime = block.timestamp - makerAsk.startTime;
        price = startPrice - elapsedTime * decayPerSecond;

        if (takerBid.maxPrice < price) {
            revert BidTooLow();
        }

        isNonceInvalidated = true;

        itemIds = makerAsk.itemIds;
        amounts = makerAsk.amounts;
    }

    /**
     * @notice This function validates *only the maker* order under the context of the chosen strategy.
     *         It does not revert if the maker order is invalid. Instead it returns false and the error's 4 bytes selector.
     * @param makerAsk Maker ask struct (contains the maker bid-specific parameters for the execution of the transaction)
     * @param functionSelector Function selector for the strategy
     * @dev The client has to provide the seller's desired initial start price as the additionalParameters.
     * @return isValid Whether the maker struct is valid
     * @return errorSelector If isValid is false, it returns the error's 4 bytes selector
     */
    function isMakerAskValid(
        OrderStructs.MakerAsk calldata makerAsk,
        bytes4 functionSelector
    ) external pure returns (bool isValid, bytes4 errorSelector) {
        if (functionSelector != StrategyDutchAuction.executeStrategyWithTakerBid.selector) {
            return (isValid, WrongFunctionSelector.selector);
        }

        uint256 itemIdsLength = makerAsk.itemIds.length;

        if (itemIdsLength == 0 || itemIdsLength != makerAsk.amounts.length) {
            return (isValid, OrderInvalid.selector);
        }

        for (uint256 i; i < itemIdsLength; ) {
            uint256 amount = makerAsk.amounts[i];
            if (amount != 1) {
                if (amount == 0) {
                    return (isValid, OrderInvalid.selector);
                }
                if (makerAsk.assetType == 0) {
                    return (isValid, OrderInvalid.selector);
                }
            }

            unchecked {
                ++i;
            }
        }

        uint256 startPrice = abi.decode(makerAsk.additionalParameters, (uint256));

        if (startPrice < makerAsk.minPrice) {
            return (isValid, OrderInvalid.selector);
        }

        isValid = true;
    }
}
