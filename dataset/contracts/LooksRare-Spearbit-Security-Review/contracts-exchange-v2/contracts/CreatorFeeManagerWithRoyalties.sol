// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IERC2981} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC2981.sol";

// Interfaces
import {ICreatorFeeManager} from "./interfaces/ICreatorFeeManager.sol";
import {IRoyaltyFeeRegistry} from "./interfaces/IRoyaltyFeeRegistry.sol";

/**
 * @title CreatorFeeManagerWithRoyalties
 * @notice This contract retrieves the creator fee addresses and calculates the royalties.
 * @author LooksRare protocol team (ðŸ‘€,ðŸ’Ž)
 */
contract CreatorFeeManagerWithRoyalties is ICreatorFeeManager {
    /**
     * @notice Royalty fee registry interface.
     */
    IRoyaltyFeeRegistry public immutable royaltyFeeRegistry;

    /**
     * @notice Constructor
     * @param _royaltyFeeRegistry Royalty fee registry address.
     */
    constructor(address _royaltyFeeRegistry) {
        royaltyFeeRegistry = IRoyaltyFeeRegistry(_royaltyFeeRegistry);
    }

    /**
     * @inheritdoc ICreatorFeeManager
     * @dev There are two on-chain sources for the royalty fee to distribute.
     *      1. RoyaltyFeeRegistry: It is an on-chain registry where royalty fee is defined across all items of a collection.
     *      2. ERC2981: The NFT Royalty Standard where royalty fee is defined at a itemId level for each item of a collection.
     *      The on-chain logic looks up the registry first. If it doesn't find anything, it checks if a collection is ERC2981.
     *      If so, it fetches the proper royalty information for the itemId.
     *      For a bundle that contains multiple itemIds (for a collection using ERC2981), if the royalty fee/recipient differ among the itemIds
     *      part of the bundle, the trade reverts.
     *      This contract DOES NOT enforce any restriction for extremely high creator fee, not verifies the creator fee fetched is inferior to the total price.
     *      If any contract relies on it to build an on-chain royalty logic, the contract should implement protection against (1) high
     *      royalties or (2) potential unexpected royalty changes that can occur after the creation of the order.
     */
    function viewCreatorFeeInfo(
        address collection,
        uint256 price,
        uint256[] memory itemIds
    ) external view returns (address creator, uint256 creatorFee) {
        // Check if there is a royalty info in the system
        (creator, creatorFee) = royaltyFeeRegistry.royaltyInfo(collection, price);

        if (creator == address(0)) {
            if (IERC2981(collection).supportsInterface(IERC2981.royaltyInfo.selector)) {
                uint256 length = itemIds.length;

                for (uint256 i; i < length; ) {
                    (bool status, bytes memory data) = collection.staticcall(
                        abi.encodeWithSelector(IERC2981.royaltyInfo.selector, itemIds[i], price)
                    );

                    if (status) {
                        (address newCreator, uint256 newCreatorFee) = abi.decode(data, (address, uint256));

                        if (i == 0) {
                            creator = newCreator;
                            creatorFee = newCreatorFee;
                        } else {
                            if (newCreator != creator || newCreatorFee != creatorFee) {
                                revert BundleEIP2981NotAllowed(collection);
                            }
                        }
                    }

                    unchecked {
                        ++i;
                    }
                }
            }
        }
    }
}
