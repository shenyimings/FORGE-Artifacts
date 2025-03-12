// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @notice Thrown when trying to seal a sealId which has already been used.
/// @param sealId The seal identifier.
error AlreadySealed(uint256 sealId);
