// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import {IERC721BatchTransfer} from "../ERC721/IERC721BatchTransfer.sol";

/**
 * @title IERC1155721InventoryBurnable interface.
 */
interface IERC1155721BatchTransfer is IERC721BatchTransfer {
    /**
     * @notice this documentation overrides its IERC721BatchTransfer counterpart.
     * Unsafely transfers a batch of non-fungible tokens.
     * @dev Usage of this method is discouraged, use `safeTransferFrom` whenever possible
     * @dev Reverts if `to` is the zero address.
     * @dev Reverts if the sender is not approved.
     * @dev Reverts if one of `nftIds` is not owned by `from`.
     * @dev Reverts if `to` is an IERC1155TokenReceiver which refuses the transfer.
     * @dev Resets the token approval for each of `nftIds`.
     * @dev Emits an {IERC721-Transfer} event for each of `nftIds`.
     * @dev Emits an {IERC1155-TransferBatch} event.
     * @param from Current tokens owner.
     * @param to Address of the new tokens owner.
     * @param nftIds Identifiers of the tokens to transfer.
     */
    // function batchTransferFrom(
    //     address from,
    //     address to,
    //     uint256[] calldata nftIds
    // ) external;
}
