// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../interfaces/ISmartVault.sol";
import "../access/SpoolAccessControllable.sol";

/* ========== ERRORS ========== */

/**
 * @notice Used when caller is not allowed to manage the allowlist for the smart vault.
 * @param caller Address of the caller.
 * @param smartVault Address of the smart vault.
 */
error CallerNotAllowlistManager(address caller, address smartVault);

/* ========== CONTRACTS ========== */

contract AllowlistGuard is SpoolAccessControllable {
    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when addresses are added to the allowlist for the smart vault.
     * @param smartVault Address of the smart vault.
     * @param allowlistId ID of the allowlist of the smart vault.
     * @param addresses Addresses added to the allowlist.
     */
    event AddedToAllowlist(address indexed smartVault, uint256 indexed allowlistId, address[] addresses);

    /**
     * @notice Emitted when addresses are removed from the allowlist for the smart vault.
     * @param smartVault Address of the smart vault.
     * @param allowlistId ID of the allowlist of the smart vault.
     * @param addresses Addresses removed from the allowlist.
     */
    event RemovedFromAllowlist(address indexed smartVault, uint256 indexed allowlistId, address[] addresses);

    /* ========== STATE VARIABLES ========== */

    /**
     * @notice Allowlists for a smart vault.
     * Each smart vault can have multiple allowlists, differentiated by an ID.
     */
    mapping(address => mapping(uint256 => mapping(address => bool))) private allowlists;

    constructor(ISpoolAccessControl accessControl_) SpoolAccessControllable(accessControl_) {}

    /* ========== EXTERNAL VIEW FUNCTIONS ========== */

    /**
     * @notice Check if address is on allowlist for a smart vault.
     * @param smartVault Address of the smart vault.
     * @param allowlistId ID of the allowlist for the smart vault.
     * @param address_ Address to check.
     * @return allowed True when address is on the allowlist, false otherwise.
     */
    function isAllowed(address smartVault, uint256 allowlistId, address address_) external view returns (bool) {
        return allowlists[smartVault][allowlistId][address_];
    }

    /* ========== EXTERNAL MUTATIVE FUNCTIONS ========== */

    /**
     * @notice Add addresses to allowlist for a smart vault.
     * @dev Requirements:
     * - caller must be set as allowlist manager on the smart vault
     * @param smartVault Address of the smart vault.
     * @param allowlistId ID of the allowlist for the smart vault.
     * @param addresses Addresses to add to the allowlist.
     */
    function addToAllowlist(address smartVault, uint256 allowlistId, address[] calldata addresses)
        external
        onlySmartVaultRole(smartVault, ROLE_GUARD_ALLOWLIST_MANAGER, msg.sender)
    {
        for (uint256 i; i < addresses.length; ++i) {
            allowlists[smartVault][allowlistId][addresses[i]] = true;
        }

        emit AddedToAllowlist(smartVault, allowlistId, addresses);
    }

    /**
     * @notice Remove addresses from allowlist for a smart vault.
     * @dev Requirements:
     * - caller must be set as allowlist manager on the smart vault
     * @param smartVault Address of the smart vault.
     * @param allowlistId ID of the allowlist for the smart vault.
     * @param addresses Addresses to remove from the allowlist.
     */
    function removeFromAllowlist(address smartVault, uint256 allowlistId, address[] calldata addresses)
        external
        onlySmartVaultRole(smartVault, ROLE_GUARD_ALLOWLIST_MANAGER, msg.sender)
    {
        for (uint256 i; i < addresses.length; ++i) {
            allowlists[smartVault][allowlistId][addresses[i]] = false;
        }

        emit RemovedFromAllowlist(smartVault, allowlistId, addresses);
    }
}
