// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @notice Thrown when the initial admin is not set.
error NoInitialProxyAdmin();

/// @notice Thrown when an account is not the proxy admin but is required to.
/// @param account The account that was checked.
error NotProxyAdmin(address account);
