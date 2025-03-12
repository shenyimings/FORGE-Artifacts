// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @notice Emitted when `role` is granted to `account`.
/// @param role The role that has been granted.
/// @param account The account that has been granted the role.
/// @param operator The account that granted the role.
event RoleGranted(bytes32 role, address account, address operator);

/// @notice Emitted when `role` is revoked from `account`.
/// @param role The role that has been revoked.
/// @param account The account that has been revoked the role.
/// @param operator The account that revoked the role.
event RoleRevoked(bytes32 role, address account, address operator);
