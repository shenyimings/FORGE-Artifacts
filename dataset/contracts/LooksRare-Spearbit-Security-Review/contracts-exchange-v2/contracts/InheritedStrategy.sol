// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "./libraries/OrderStructs.sol";

// Shared errors
import {OrderInvalid} from "./interfaces/SharedErrors.sol";

/**
 * @title InheritedStrategy
 * @notice This contract handles the verification of parameters for standard transactions.
 * @dev A standard transaction (bid or ask) is mapped to strategyId = 0.
 * @author LooksRare protocol team (ðŸ‘€,ðŸ’Ž)
 */
contract InheritedStrategy {
    /**
     * @notice This function is internal and is used to validate the parameters for a standard sale strategy
     *         when the standard transaction is initiated by a taker bid.
     * @param takerBid Taker bid struct (contains the taker bid-specific parameters for the execution of the transaction)
     * @param makerAsk Maker ask struct (contains the maker ask-specific parameters for the execution of the transaction)
     */
    function _verifyStandardSaleStrategyWithTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk
    ) internal pure {
        _verifyMatchingItemIdsAndAmountsAndPrice(
            makerAsk.assetType,
            makerAsk.amounts,
            takerBid.amounts,
            makerAsk.itemIds,
            takerBid.itemIds,
            makerAsk.minPrice,
            takerBid.maxPrice
        );
    }

    /**
     * @notice This function is internal and is used to validate the parameters for a standard sale strategy
     *         when the standard transaction is initiated by a taker ask.
     * @param takerAsk Taker ask struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid Maker bid struct (contains the maker bid-specific parameters for the execution of the transaction)
     */
    function _verifyStandardSaleStrategyWithTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    ) internal pure {
        _verifyMatchingItemIdsAndAmountsAndPrice(
            makerBid.assetType,
            makerBid.amounts,
            takerAsk.amounts,
            makerBid.itemIds,
            takerAsk.itemIds,
            makerBid.maxPrice,
            takerAsk.minPrice
        );
    }

    function _verifyMatchingItemIdsAndAmountsAndPrice(
        uint256 assetType,
        uint256[] calldata amounts,
        uint256[] calldata counterpartyAmounts,
        uint256[] calldata itemIds,
        uint256[] calldata counterpartyItemIds,
        uint256 price,
        uint256 counterpartyPrice
    ) private pure {
        uint256 amountsLength = amounts.length;

        {
            uint256 counterpartyAmountsLength = counterpartyAmounts.length;
            uint256 itemIdsLength = itemIds.length;
            uint256 counterpartyItemIdsLength = counterpartyItemIds.length;

            // if (
            //     amountsLength == 0 ||
            //     // If A == B, then A XOR B == 0. So if all 4 are equal, it should be 0 | 0 | 0 == 0
            //     ((amountsLength ^ itemIdsLength) |
            //         (counterpartyItemIdsLength ^ counterpartyAmountsLength) |
            //         (amountsLength ^ counterpartyItemIdsLength)) !=
            //     0 ||
            //     price != counterpartyPrice
            // ) {
            //     revert OrderInvalid();
            // }
            assembly {
                if or(
                    or(iszero(amountsLength), iszero(eq(price, counterpartyPrice))),
                    gt(
                        or(
                            or(
                                xor(amountsLength, itemIdsLength),
                                xor(counterpartyItemIdsLength, counterpartyAmountsLength)
                            ),
                            xor(amountsLength, counterpartyItemIdsLength)
                        ),
                        0
                    )
                ) {
                    mstore(0x00, 0x2e0c0f71)
                    revert(0x1c, 0x04)
                }
            }
        }

        for (uint256 i; i < amountsLength; ) {
            uint256 amount = amounts[i];

            if ((amount != counterpartyAmounts[i]) || (itemIds[i] != counterpartyItemIds[i])) {
                revert OrderInvalid();
            }

            if (amount != 1) {
                if (amount == 0) {
                    revert OrderInvalid();
                }
                if (assetType == 0) {
                    revert OrderInvalid();
                }
            }

            unchecked {
                ++i;
            }
        }
    }
}
