// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @notice Thrown when the contract is paused but is required not to.
error Paused();

/// @notice Thrown when the contract is not paused but is required to.
error NotPaused();
