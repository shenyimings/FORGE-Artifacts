// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC20Storage} from "./libraries/ERC20Storage.sol";
import {ERC20MintableBase} from "./base/ERC20MintableBase.sol";
import {AccessControl} from "./../../access/AccessControl.sol";

/// @title ERC20 Fungible Token Standard, optional extension: Mintable (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC20Mintable is ERC20MintableBase, AccessControl {
    /// @notice Marks the following ERC165 interface(s) as supported: ERC20Mintable.
    constructor() {
        ERC20Storage.initERC20Mintable();
    }
}
