// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

/**
 * @title IERC1155721InventoryDeliverable interface.
 */
interface IERC1155721InventoryDeliverable {
    /**
     * Safely mints some tokens to a list of recipients.
     * @dev Reverts if `recipients`, `ids` and `values` have different lengths.
     * @dev Reverts if one of `recipients` is the zero address.
     * @dev Reverts if one of `ids` is not a token.
     * @dev Reverts if one of `ids` represents a non-fungible token and its `value` is not 1.
     * @dev Reverts if one of `ids` represents a non-fungible token which has already been minted.
     * @dev Reverts if one of `ids` represents a fungible token and its `value` is 0.
     * @dev Reverts if one of `ids` represents a fungible token and there is an overflow of supply.
     * @dev Reverts if one of `recipients` is a contract and the call to {IERC1155TokenReceiver-onERC1155Received} fails or is refused.
     * @dev Emits an {IERC721-Transfer} event from the zero address for each `id` representing a non-fungible token.
     * @dev Emits an {IERC1155-TransferSingle} event from the zero address.
     * @param recipients Addresses of the new token owners.
     * @param ids Identifiers of the tokens to mint.
     * @param values Amounts of tokens to mint.
     * @param data Optional data to send along to the receiver contract(s), if any. All receivers receive the same data.
     */
    function safeDeliver(
        address[] calldata recipients,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external;
}
