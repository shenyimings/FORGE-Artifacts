// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @notice Thrown when an account is not the metadata resolver but is required to.
/// @param account The account that was checked.
error NotMetadataResolver(address account);
