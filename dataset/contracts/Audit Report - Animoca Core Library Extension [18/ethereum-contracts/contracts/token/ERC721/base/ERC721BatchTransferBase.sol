// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IERC721Events} from "./../events/IERC721Events.sol";
import {IERC721BatchTransfer} from "./../interfaces/IERC721BatchTransfer.sol";
import {ERC721Storage} from "./../libraries/ERC721Storage.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

/// @title ERC721 Non-Fungible Token Standard, optional extension: Batch Transfer (proxiable version).
/// @dev This contract is to be used via inheritance in a proxied implementation.
/// @dev Note: This contract requires ERC721 (Non-Fungible Token Standard).
abstract contract ERC721BatchTransferBase is IERC721Events, IERC721BatchTransfer, Context {
    using ERC721Storage for ERC721Storage.Layout;

    /// @inheritdoc IERC721BatchTransfer
    function batchTransferFrom(address from, address to, uint256[] calldata tokenIds) external virtual {
        ERC721Storage.layout().batchTransferFrom(_msgSender(), from, to, tokenIds);
    }
}
