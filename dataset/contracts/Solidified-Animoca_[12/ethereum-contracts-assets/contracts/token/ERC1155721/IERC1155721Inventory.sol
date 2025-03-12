// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import {IERC1155Inventory} from "../ERC1155/IERC1155Inventory.sol";
import {IERC1155721} from "./IERC1155721.sol";

/**
 * @title IERC1155721Inventory interface.
 */
interface IERC1155721Inventory is IERC1155721, IERC1155Inventory {
    /// @dev See {IERC721-ownerOf(uint256)} and {IERC1155Inventory-ownerOf(uint256)}.
    function ownerOf(uint256 nftId) external view override(IERC1155721, IERC1155Inventory) returns (address);

    /**
     * @notice this documentation overrides {IERC1155Inventory-safeTransferFrom(address,address,uint256,uint256,bytes)}.
     * Safely transfers some token.
     * @dev Reverts if `to` is the zero address.
     * @dev Reverts if the sender is not approved.
     * @dev Reverts if `id` does not represent a token.
     * @dev Reverts if `id` represents a non-fungible token and `value` is not 1.
     * @dev Reverts if `id` represents a non-fungible token and is not owned by `from`.
     * @dev Reverts if `id` represents a fungible token and `value` is 0.
     * @dev Reverts if `id` represents a fungible token and `from` has an insufficient balance.
     * @dev Reverts if `to` is a contract and the call to {IERC1155TokenReceiver-onERC1155received} fails or is refused.
     * @dev Resets the ERC721 single token approval if `id` represents a non-fungible token.
     * @dev Emits an {IERC721-Transfer} event if `id` represents a non-fungible token.
     * @dev Emits an {IERC1155-TransferSingle} event.
     * @param from Current token owner.
     * @param to Address of the new token owner.
     * @param id Identifier of the token to transfer.
     * @param value Amount of token to transfer.
     * @param data Optional data to pass to the receiver contract.
     */
    // function safeTransferFrom(
    //     address from,
    //     address to,
    //     uint256 id,
    //     uint256 value,
    //     bytes calldata data
    // ) external;
    /**
     * @notice this documentation overrides {IERC1155Inventory-safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)}.
     * Safely transfers a batch of tokens.
     * @dev Reverts if `to` is the zero address.
     * @dev Reverts if the sender is not approved.
     * @dev Reverts if one of `ids` does not represent a token.
     * @dev Reverts if one of `ids` represents a non-fungible token and `value` is not 1.
     * @dev Reverts if one of `ids` represents a non-fungible token and is not owned by `from`.
     * @dev Reverts if one of `ids` represents a fungible token and `value` is 0.
     * @dev Reverts if one of `ids` represents a fungible token and `from` has an insufficient balance.
     * @dev Reverts if one of `to` is a contract and the call to {IERC1155TokenReceiver-onERC1155batchReceived} fails or is refused.
     * @dev Resets the ERC721 single token approval for each transferred non-fungible token.
     * @dev Emits an {IERC721-Transfer} event for each transferred non-fungible token.
     * @dev Emits an {IERC1155-TransferBatch} event.
     * @param from Current tokens owner.
     * @param to Address of the new tokens owner.
     * @param ids Identifiers of the tokens to transfer.
     * @param values Amounts of tokens to transfer.
     * @param data Optional data to pass to the receiver contract.
     */
    // function safeBatchTransferFrom(
    //     address from,
    //     address to,
    //     uint256[] calldata ids,
    //     uint256[] calldata values,
    //     bytes calldata data
    // ) external;
    /**
     * @notice this documentation overrides its IERC721 counterpart.
     * Unsafely transfers a Non-Fungible Token.
     * @dev Usage of this method is discouraged, use `safeTransferFrom` whenever possible
     * @dev Reverts if `to` is the zero address.
     * @dev Reverts if the sender is not approved.
     * @dev Reverts if `nftId` is not owned by `from`.
     * @dev Reverts if `to` is an IERC1155TokenReceiver contract which refuses the receiver call.
     * @dev Resets the ERC721 single token approval.
     * @dev Emits an {IERC721-Transfer} event.
     * @dev Emits an {IERC1155-TransferSingle} event.
     * @param from Current token owner.
     * @param to Address of the new token owner.
     * @param nftId Identifier of the token to transfer.
     */
    // function transferFrom(
    //     address from,
    //     address to,
    //     uint256 nftId
    // ) external;
    /**
     * @notice this documentation overrides its IERC721 counterpart.
     * Safely transfers a Non-Fungible Token.
     * @dev Reverts if `to` is the zero address.
     * @dev Reverts if the sender is not approved.
     * @dev Reverts if `nftId` is not owned by `from`.
     * @dev Reverts if `to` is a contract which does not implement IERC1155TokenReceiver or IERC721Receiver.
     * @dev Reverts if `to` is an IERC1155TokenReceiver or IERC721Receiver contract which refuses the transfer.
     * @dev Resets the ERC721 single token approval.
     * @dev Emits an {IERC721-Transfer} event.
     * @dev Emits an {IERC1155-TransferSingle} event.
     * @param from Current token owner.
     * @param to Address of the new token owner.
     * @param nftId Identifier of the token to transfer.
     */
    // function safeTransferFrom(
    //     address from,
    //     address to,
    //     uint256 nftId
    // ) external;
    /**
     * @notice this documentation overrides its IERC721 counterpart.
     * Safely transfers a Non-Fungible Token.
     * @dev Reverts if `to` is the zero address.
     * @dev Reverts if the sender is not approved.
     * @dev Reverts if `nftId` is not owned by `from`.
     * @dev Reverts if `to` is a contract which does not implement IERC1155TokenReceiver or IERC721Receiver.
     * @dev Reverts if `to` is an IERC1155TokenReceiver or IERC721Receiver contract which refuses the transfer.
     * @dev Resets the ERC721 single token approval.
     * @dev Emits an {IERC721-Transfer} event.
     * @dev Emits an {IERC1155-TransferSingle} event.
     * @param from Current token owner.
     * @param to Address of the new token owner.
     * @param nftId Identifier of the token to transfer.
     * @param data Optional data to pass to the receiver contract.
     */
    // function safeTransferFrom(
    //     address from,
    //     address to,
    //     uint256 nftId,
    //     bytes calldata data
    // ) external;
}
