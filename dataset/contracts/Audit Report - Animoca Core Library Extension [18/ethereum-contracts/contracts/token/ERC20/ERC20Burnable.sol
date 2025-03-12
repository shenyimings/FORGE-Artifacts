// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC20Storage} from "./libraries/ERC20Storage.sol";
import {ERC20BurnableBase} from "./base/ERC20BurnableBase.sol";

/// @title ERC20 Fungible Token Standard, optional extension: Burnable (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC20Burnable is ERC20BurnableBase {
    /// @notice Marks the following ERC165 interface(s) as supported: ERC20Burnable.
    constructor() {
        ERC20Storage.initERC20Burnable();
    }
}
