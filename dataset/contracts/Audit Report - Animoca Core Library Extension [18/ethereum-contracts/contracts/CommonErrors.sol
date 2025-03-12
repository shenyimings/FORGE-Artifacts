// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @notice Thrown when trying to transfer tokens without calldata to the contract.
error EtherReceptionDisabled();

/// @notice Thrown when the multiple related arrays have different lengths.
error InconsistentArrayLengths();
