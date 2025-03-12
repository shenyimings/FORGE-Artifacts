// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ProxyAdminStorage} from "./libraries/ProxyAdminStorage.sol";
import {ProxyAdminBase} from "./base/ProxyAdminBase.sol";

/// @title ERC1967 Standard Proxy Storage Slots, Admin Address (immutable version).
/// @dev See https://eips.ethereum.org/EIPS/eip-1967
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ProxyAdmin is ProxyAdminBase {
    using ProxyAdminStorage for ProxyAdminStorage.Layout;

    /// @notice Initializes the storage with an initial admin.
    /// @dev Emits an {AdminChanged} event if `initialAdmin` is not the zero address.
    /// @param initialAdmin The initial payout wallet.
    constructor(address initialAdmin) {
        ProxyAdminStorage.layout().constructorInit(initialAdmin);
    }
}
