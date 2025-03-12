// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @notice Thrown when an account does not have the required role.
/// @param role The role the caller is missing.
/// @param account The account that was checked.
error NotRoleHolder(bytes32 role, address account);

/// @notice Thrown when an account does not have the required role on a target contract.
/// @param targetContract The contract that was checked.
/// @param role The role that was checked.
/// @param account The account that was checked.
error NotTargetContractRoleHolder(address targetContract, bytes32 role, address account);
