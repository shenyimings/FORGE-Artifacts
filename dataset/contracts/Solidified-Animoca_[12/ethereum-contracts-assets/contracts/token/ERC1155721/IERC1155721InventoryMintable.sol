// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

/**
 * @title IERC1155721InventoryMintable interface.
 * The function {IERC721Mintable-safeMint(address,uint256,bytes)} is not provided as
 *  {IERC1155Mintable-safeMint(address,uint256,uint256,bytes)} can be used instead.
 */
interface IERC1155721InventoryMintable {
    /**
     * Safely mints some token (ERC1155-compatible).
     * @dev Reverts if `to` is the zero address.
     * @dev Reverts if `id` is not a token.
     * @dev Reverts if `id` represents a non-fungible token and `value` is not 1.
     * @dev Reverts if `id` represents a non-fungible token which has already been minted.
     * @dev Reverts if `id` represents a fungible token and `value` is 0.
     * @dev Reverts if `id` represents a fungible token and there is an overflow of supply.
     * @dev Reverts if `to` is a contract and the call to {IERC1155TokenReceiver-onERC1155Received} fails or is refused.
     * @dev Emits an {IERC721-Transfer} event from the zero address if `id` represents a non-fungible token.
     * @dev Emits an {IERC1155-TransferSingle} event from the zero address.
     * @param to Address of the new token owner.
     * @param id Identifier of the token to mint.
     * @param value Amount of token to mint.
     * @param data Optional data to send along to a receiver contract.
     */
    function safeMint(
        address to,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external;

    /**
     * Safely mints a batch of tokens (ERC1155-compatible).
     * @dev Reverts if `ids` and `values` have different lengths.
     * @dev Reverts if `to` is the zero address.
     * @dev Reverts if one of `ids` is not a token.
     * @dev Reverts if one of `ids` represents a non-fungible token and its paired value is not 1.
     * @dev Reverts if one of `ids` represents a non-fungible token which has already been minted.
     * @dev Reverts if one of `ids` represents a fungible token and its paired value is 0.
     * @dev Reverts if one of `ids` represents a fungible token and there is an overflow of supply.
     * @dev Reverts if `to` is a contract and the call to {IERC1155TokenReceiver-onERC1155batchReceived} fails or is refused.
     * @dev Emits an {IERC721-Transfer} event from the zero address for each non-fungible token minted.
     * @dev Emits an {IERC1155-TransferBatch} event from the zero address.
     * @param to Address of the new tokens owner.
     * @param ids Identifiers of the tokens to mint.
     * @param values Amounts of tokens to mint.
     * @param data Optional data to send along to a receiver contract.
     */
    function safeBatchMint(
        address to,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external;

    /**
     * Unsafely mints a Non-Fungible Token (ERC721-compatible).
     * @dev Reverts if `to` is the zero address.
     * @dev Reverts if `nftId` does not represent a non-fungible token.
     * @dev Reverts if `nftId` has already been minted.
     * @dev Emits an {IERC721-Transfer} event from the zero address.
     * @dev Emits an {IERC1155-TransferSingle} event from the zero address.
     * @dev If `to` is a contract and supports ERC1155TokenReceiver, calls {IERC1155TokenReceiver-onERC1155Received} with empty data.
     * @param to Address of the new token owner.
     * @param nftId Identifier of the token to mint.
     */
    function mint(address to, uint256 nftId) external;

    /**
     * Unsafely mints a batch of Non-Fungible Tokens (ERC721-compatible).
     * @dev Reverts if `to` is the zero address.
     * @dev Reverts if one of `nftIds` does not represent a non-fungible token.
     * @dev Reverts if one of `nftIds` has already been minted.
     * @dev Emits an {IERC721-Transfer} event from the zero address for each of `nftIds`.
     * @dev Emits an {IERC1155-TransferBatch} event from the zero address.
     * @dev If `to` is a contract and supports ERC1155TokenReceiver, calls {IERC1155TokenReceiver-onERC1155BatchReceived} with empty data.
     * @param to Address of the new token owner.
     * @param nftIds Identifiers of the tokens to mint.
     */
    function batchMint(address to, uint256[] calldata nftIds) external;

    /**
     * Safely mints a token (ERC721-compatible).
     * @dev Reverts if `to` is the zero address.
     * @dev Reverts if `tokenId` has already ben minted.
     * @dev Reverts if `to` is a contract which does not implement IERC721Receiver or IERC1155TokenReceiver.
     * @dev Reverts if `to` is an IERC1155TokenReceiver or IERC721TokenReceiver contract which refuses the transfer.
     * @dev Emits an {IERC721-Transfer} event from the zero address.
     * @dev Emits an {IERC1155-TransferSingle} event from the zero address.
     * @param to Address of the new token owner.
     * @param nftId Identifier of the token to mint.
     * @param data Optional data to pass along to the receiver call.
     */
    function safeMint(
        address to,
        uint256 nftId,
        bytes calldata data
    ) external;
}
