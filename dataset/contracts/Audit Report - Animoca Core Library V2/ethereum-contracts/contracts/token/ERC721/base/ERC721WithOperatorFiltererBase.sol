// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC721} from "./../interfaces/IERC721.sol";
import {ERC721Storage} from "./../libraries/ERC721Storage.sol";
import {OperatorFiltererStorage} from "./../../royalty/libraries/OperatorFiltererStorage.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

/// @title ERC721 Non-Fungible Token Standard with Operator Filterer (proxiable version).
/// @dev This contract is to be used via inheritance in a proxied implementation.
/// @dev Note: This contract requires ERC165 (Interface Detection Standard).
/// @dev Note: This contract requires OperatorFilterer.
abstract contract ERC721WithOperatorFiltererBase is IERC721, Context {
    using ERC721Storage for ERC721Storage.Layout;
    using OperatorFiltererStorage for OperatorFiltererStorage.Layout;

    /// @inheritdoc IERC721
    /// @dev Reverts with {OperatorNotAllowed} if `to` is not the zero address and is not allowed by the operator registry.
    function approve(address to, uint256 tokenId) external virtual {
        if (to != address(0)) {
            OperatorFiltererStorage.layout().requireAllowedOperatorForApproval(to);
        }
        ERC721Storage.layout().approve(_msgSender(), to, tokenId);
    }

    /// @inheritdoc IERC721
    /// @dev Reverts with {OperatorNotAllowed} if `approved` is true and `operator` is not allowed by the operator registry.
    function setApprovalForAll(address operator, bool approved) external virtual {
        if (approved) {
            OperatorFiltererStorage.layout().requireAllowedOperatorForApproval(operator);
        }
        ERC721Storage.layout().setApprovalForAll(_msgSender(), operator, approved);
    }

    /// @inheritdoc IERC721
    /// @dev Reverts with {OperatorNotAllowed} if the sender is not `from` and is not allowed by the operator registry.
    function transferFrom(address from, address to, uint256 tokenId) external {
        address sender = _msgSender();
        OperatorFiltererStorage.layout().requireAllowedOperatorForTransfer(sender, from);
        ERC721Storage.layout().transferFrom(sender, from, to, tokenId);
    }

    /// @inheritdoc IERC721
    /// @dev Reverts with {OperatorNotAllowed} if the sender is not `from` and is not allowed by the operator registry.
    function safeTransferFrom(address from, address to, uint256 tokenId) external virtual {
        address sender = _msgSender();
        OperatorFiltererStorage.layout().requireAllowedOperatorForTransfer(sender, from);
        ERC721Storage.layout().safeTransferFrom(sender, from, to, tokenId);
    }

    /// @inheritdoc IERC721
    /// @dev Reverts with {OperatorNotAllowed} if the sender is not `from` and is not allowed by the operator registry.
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external virtual {
        address sender = _msgSender();
        OperatorFiltererStorage.layout().requireAllowedOperatorForTransfer(sender, from);
        ERC721Storage.layout().safeTransferFrom(sender, from, to, tokenId, data);
    }

    /// @inheritdoc IERC721
    function balanceOf(address owner) external view returns (uint256 balance) {
        return ERC721Storage.layout().balanceOf(owner);
    }

    /// @inheritdoc IERC721
    function ownerOf(uint256 tokenId) external view returns (address tokenOwner) {
        return ERC721Storage.layout().ownerOf(tokenId);
    }

    /// @inheritdoc IERC721
    function getApproved(uint256 tokenId) external view returns (address approved) {
        return ERC721Storage.layout().getApproved(tokenId);
    }

    /// @inheritdoc IERC721
    function isApprovedForAll(address owner, address operator) external view returns (bool approvedForAll) {
        return ERC721Storage.layout().isApprovedForAll(owner, operator);
    }
}
