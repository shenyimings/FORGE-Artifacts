// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @notice Thrown when an account is not the contract owner but is required to.
/// @param account The account that was checked.
error NotContractOwner(address account);

/// @notice Thrown when an account is not the target contract owner but is required to.
/// @param targetContract The contract that was checked.
/// @param account The account that was checked.
error NotTargetContractOwner(address targetContract, address account);
