// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @title ERC1967 Standard Proxy Storage Slots, Admin Address (events).
/// @dev See https://eips.ethereum.org/EIPS/eip-1967
interface IProxyAdminEvents {
    /// @notice Emitted when the proxy admin changes.
    /// @param previousAdmin the previous admin.
    /// @param newAdmin the new admin.
    event AdminChanged(address previousAdmin, address newAdmin);
}
