// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

/**
 * @title ERC721 Non-Fungible Token Standard, optional burning interface
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 * Note: The ERC-165 identifier for this interface is.
 */
interface IERC721Burnable {
    /**
     * Burns a token.
     * @dev Reverts if the sender is not approved.
     * @dev Reverts if `tokenId` is not owned by `from`.
     * @dev Emits an {IERC721-Transfer} event to address zero.
     * @param from Current token owner.
     * @param tokenId Identifier of the token to burn.
     */
    function burnFrom(address from, uint256 tokenId) external;

    /**
     * Burns a batch of tokens.
     * @dev Reverts if the sender is not approved for any of `tokenIds`.
     * @dev Reverts if one of `tokenIds` is not owned by `from`.
     * @dev Emits an {IERC721-Transfer} event to address zero for each of `tokenIds`.
     * @param from Current tokens owner.
     * @param tokenIds Identifiers of the tokens to burn.
     */
    function batchBurnFrom(address from, uint256[] calldata tokenIds) external;
}
