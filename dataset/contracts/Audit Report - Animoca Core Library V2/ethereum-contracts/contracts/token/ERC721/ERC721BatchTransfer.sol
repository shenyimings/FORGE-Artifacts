// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC721Storage} from "./libraries/ERC721Storage.sol";
import {ERC721BatchTransferBase} from "./base/ERC721BatchTransferBase.sol";

/// @title ERC721 Non-Fungible Token Standard: optional extension: BatchTransfer (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC721BatchTransfer is ERC721BatchTransferBase {
    /// @notice Marks the following ERC165 interfaces(s) as supported: ERC721BatchTransfer
    constructor() {
        ERC721Storage.initERC721BatchTransfer();
    }
}
