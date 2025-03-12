//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @title Claim Manager
 * @dev Interface for managing claims and roles for the Greenproof smart contract.
 * @author EnergyWeb Foundation
 */
interface IClaimManager {
    /**
     * @notice hasRole - checks wether an address has a specific role with a specific version
     * @param subject The address to check.
     * @param role The name of the role to check for.
     * @param version The version of the role to check for.
     * @return true if the `_subject` is enrolled to the `_role` role and with the `_version` version, false otherwise
     */
    function hasRole(address subject, bytes32 role, uint256 version) external view returns (bool);

    /**
     * @dev Check if a certain role is revoked for a subject
     * @param role bytes32 representation of the role to check
     * @param subject address of the subject to check
     * @return bool indicating if the role is revoked for the subject
     */
    function isRevoked(bytes32 role, address subject) external view returns (bool);
}
