// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @notice Thrown when transferring to or giving approval to a non-authorized operator.
/// @param operator The address that is not authorized.
error OperatorNotAllowed(address operator);
