// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC1155Storage} from "./libraries/ERC1155Storage.sol";
import {ERC1155BurnableBase} from "./base/ERC1155BurnableBase.sol";

/// @title ERC1155 Multi Token Standard, optional extension: Burnable (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC1155Burnable is ERC1155BurnableBase {
    /// @notice Marks the fllowing ERC165 interface(s) as supported: ERC1155Burnable
    constructor() {
        ERC1155Storage.initERC1155Burnable();
    }
}
