// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;


/**
 * @title Outlines the roles used in the ZNS system
 * @dev > Inherited ONLY by `ZNSAccessController`
 */
abstract contract ZNSRoles {
    /**
     * @notice The highest rank, assigns Admins, new roles and Role Admins
     */
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    /**
     * @notice The main maintainer role, that gets access to all system functions
     */
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /**
     * @notice This role is here specifically for the ZNSRootRegistrar.sol contract
     */
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    /**
     * @notice Executor can be here to future proof, if we need a new role
     * so we don't have to upgrade all contracts
     */
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
}
