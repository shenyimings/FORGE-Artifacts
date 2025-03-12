// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC1155Storage} from "./libraries/ERC1155Storage.sol";
import {ERC1155DeliverableBase} from "./base/ERC1155DeliverableBase.sol";
import {AccessControl} from "./../../access/AccessControl.sol";

/// @title ERC1155 Multi Token Standard, optional extension: Deliverable (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC1155Deliverable is ERC1155DeliverableBase, AccessControl {
    /// @notice Marks the fllowing ERC165 interface(s) as supported: ERC1155Deliverable
    constructor() {
        ERC1155Storage.initERC1155Deliverable();
    }
}
