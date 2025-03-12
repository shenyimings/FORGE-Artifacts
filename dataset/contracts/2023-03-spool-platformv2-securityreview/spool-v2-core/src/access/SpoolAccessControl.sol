// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin-upgradeable/security/PausableUpgradeable.sol";
import "../interfaces/ISpoolAccessControl.sol";
import "./Roles.sol";

/**
 * @notice Spool access control management
 */
contract SpoolAccessControl is AccessControlUpgradeable, PausableUpgradeable, ISpoolAccessControl {
    mapping(address => address) public smartVaultOwner;

    /* ========== CONSTRUCTOR ========== */

    constructor() {}

    function initialize() public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ROLE_STRATEGY, ADMIN_ROLE_STRATEGY);
        _setRoleAdmin(ROLE_SMART_VAULT_ALLOW_REDEEM, ADMIN_ROLE_SMART_VAULT_ALLOW_REDEEM);
        __Pausable_init();
    }

    /* ========== EXTERNAL VIEW FUNCTIONS ========== */

    function hasSmartVaultRole(address smartVault, bytes32 role, address account) external view returns (bool) {
        return hasRole(_getSmartVaultRole(smartVault, role), account);
    }

    function checkIsAdminOrVaultAdmin(address smartVault, address account) external view {
        _onlyAdminOrVaultAdmin(smartVault, account);
    }

    function paused() public view override(ISpoolAccessControl, PausableUpgradeable) returns (bool) {
        return super.paused();
    }

    /* ========== EXTERNAL MUTATIVE FUNCTIONS ========== */

    function grantSmartVaultOwnership(address smartVault, address owner) external {
        if (smartVaultOwner[smartVault] != address(0)) {
            revert SmartVaultOwnerAlreadySet(smartVault);
        }

        smartVaultOwner[smartVault] = owner;
    }

    function grantSmartVaultRole(address smartVault, bytes32 role, address account)
        external
        onlyAdminOrVaultAdmin(smartVault, msg.sender)
    {
        _grantRole(_getSmartVaultRole(smartVault, role), account);
    }

    function revokeSmartVaultRole(address smartVault, bytes32 role, address account)
        external
        onlyAdminOrVaultAdmin(smartVault, msg.sender)
    {
        _revokeRole(_getSmartVaultRole(smartVault, role), account);
    }

    function renounceSmartVaultRole(address smartVault, bytes32 role) external {
        renounceRole(_getSmartVaultRole(smartVault, role), msg.sender);
    }

    function pause() external onlyRole(ROLE_PAUSER) {
        _pause();
    }

    function unpause() external onlyRole(ROLE_UNPAUSER) {
        _unpause();
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _onlyAdminOrVaultAdmin(address smartVault, address account) private view {
        bytes32 vaultAdminRole = _getSmartVaultRole(smartVault, ROLE_SMART_VAULT_ADMIN);
        if (!hasRole(DEFAULT_ADMIN_ROLE, account) && !hasRole(vaultAdminRole, account)) {
            revert MissingRole(vaultAdminRole, account);
        }
    }

    function _getSmartVaultRole(address smartVault, bytes32 role) internal pure returns (bytes32) {
        return keccak256(abi.encode(smartVault, role));
    }

    function _checkRole(bytes32 role, address account) internal view override {
        if (!hasRole(role, account)) {
            revert MissingRole(role, account);
        }
    }

    /* ========== MODIFIERS ========== */

    modifier onlyAdminOrVaultAdmin(address smartVault, address account) {
        _onlyAdminOrVaultAdmin(smartVault, account);
        _;
    }
}
