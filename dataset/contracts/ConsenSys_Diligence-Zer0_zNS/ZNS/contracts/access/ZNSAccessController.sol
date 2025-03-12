// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IZNSAccessController } from "./IZNSAccessController.sol";
import { ZNSRoles } from "./ZNSRoles.sol";


/**
 * @title The main module for system-wide Access Control.
 * @dev ZNS Business Logic Contract access to this module is outlined in `AAccessControlled.sol`.
 * Uses a role-based access control scheme with levels:
 * - GOVERNOR: The highest rank, assigns Admins, new roles and Role Admins
 * - ADMIN: The main maintainer role, that gets access to all system functions (managed by Governor)
 * - EXECUTOR: Can be here to future proof, if we need a new role (managed by Governor)
 * - REGISTRAR: This role is here specifically for the ZNSRootRegistrar.sol contract (managed by Admin)
 *
 * > This contract is NOT proxied. When new implementation is needed, a new contract will be deployed
 * and all modules will be updated to use the new address, since they all inherit from `AAccessControlled.sol`.
 */
contract ZNSAccessController is AccessControl, ZNSRoles, IZNSAccessController {
    constructor(
        address[] memory governorAddresses,
        address[] memory adminAddresses
    ) {
        // give roles to all addresses
        _grantRoleToMany(GOVERNOR_ROLE, governorAddresses);
        _grantRoleToMany(ADMIN_ROLE, adminAddresses);

        // all of the governors control admins
        _setRoleAdmin(ADMIN_ROLE, GOVERNOR_ROLE);
        // all of the governors control governors
        _setRoleAdmin(GOVERNOR_ROLE, GOVERNOR_ROLE);
        // all of the admins control registrar
        _setRoleAdmin(REGISTRAR_ROLE, ADMIN_ROLE);
    }

    // ** Access Validators **
    // "check...()" functions revert with a specific message
    function checkGovernor(address account) external view override {
        _checkRole(GOVERNOR_ROLE, account);
    }

    function checkAdmin(address account) external view override {
        _checkRole(ADMIN_ROLE, account);
    }

    function checkExecutor(address account) external view override {
        _checkRole(EXECUTOR_ROLE, account);
    }

    function checkRegistrar(address account) external view override {
        _checkRole(REGISTRAR_ROLE, account);
    }

    // "is...()" functions return a boolean
    function isAdmin(address account) external view override returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    function isRegistrar(address account) external view override returns (bool) {
        return hasRole(REGISTRAR_ROLE, account);
    }

    function isGovernor(address account) external view override returns (bool) {
        return hasRole(GOVERNOR_ROLE, account);
    }

    function isExecutor(address account) external view override returns (bool) {
        return hasRole(EXECUTOR_ROLE, account);
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole) external override onlyRole(GOVERNOR_ROLE) {
        _setRoleAdmin(role, adminRole);
    }

    function _grantRoleToMany(bytes32 role, address[] memory addresses) internal {
        uint256 length = addresses.length;
        for (uint256 i = 0; i < length; ++i) {
            require(
                addresses[i] != address(0),
                "ZNSAccessController: Can't grant role to zero address"
            );
            _grantRole(role, addresses[i]);
        }
    }
}
