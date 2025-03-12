// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC721Storage} from "./libraries/ERC721Storage.sol";
import {ERC721BatchTransferWithOperatorFiltererBase} from "./base/ERC721BatchTransferWithOperatorFiltererBase.sol";

/// @title ERC721 Non-Fungible Token Standard: optional extension: Batch Transfer with Operator Filterer (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC721BatchTransferWithOperatorFilterer is ERC721BatchTransferWithOperatorFiltererBase {
    /// @notice Marks the following ERC165 interfaces(s) as supported: ERC721BatchTransfer
    constructor() {
        ERC721Storage.initERC721BatchTransfer();
    }
}
