// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC1155Storage} from "./libraries/ERC1155Storage.sol";
import {ERC1155MintableBase} from "./base/ERC1155MintableBase.sol";
import {AccessControl} from "./../../access/AccessControl.sol";

/// @title ERC1155 Multi Token Standard, optional extension: Mintable (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC1155Mintable is ERC1155MintableBase, AccessControl {
    /// @notice Marks the fllowing ERC165 interface(s) as supported: ERC1155Mintable
    constructor() {
        ERC1155Storage.initERC1155Mintable();
    }
}
