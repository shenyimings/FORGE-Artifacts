// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

/**
 * @title ERC721 Non-Fungible Token Standard, optional unsafe batchTransfer interface
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 * Note: The ERC-165 identifier for this interface is.
 */
interface IERC721BatchTransfer {
    /**
     * Unsafely transfers a batch of tokens.
     * @dev Usage of this method is discouraged, use `safeTransferFrom` whenever possible
     * @dev Reverts if `to` is the zero address.
     * @dev Reverts if the sender is not approved.
     * @dev Reverts if one of `tokenIds` is not owned by `from`.
     * @dev Resets the token approval for each of `tokenIds`.
     * @dev Emits an {IERC721-Transfer} event for each of `tokenIds`.
     * @param from Current tokens owner.
     * @param to Address of the new token owner.
     * @param tokenIds Identifiers of the tokens to transfer.
     */
    function batchTransferFrom(
        address from,
        address to,
        uint256[] calldata tokenIds
    ) external;
}
