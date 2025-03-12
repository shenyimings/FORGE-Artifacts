// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20PermitStorage} from "./libraries/ERC20PermitStorage.sol";
import {ERC20PermitBase} from "./base/ERC20PermitBase.sol";

/// @title ERC20 Fungible Token Standard, optional extension: Permit (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
/// @dev Note: This contract requires ERC20Detailed.
abstract contract ERC20Permit is ERC20PermitBase {
    using ERC20PermitStorage for ERC20PermitStorage.Layout;

    /// @notice Marks the following ERC165 interface(s) as supported: ERC20Permit.
    constructor() {
        ERC20PermitStorage.init();
    }
}
