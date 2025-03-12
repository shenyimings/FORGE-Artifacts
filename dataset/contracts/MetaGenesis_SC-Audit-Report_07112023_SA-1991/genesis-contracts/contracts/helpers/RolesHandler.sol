// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../interfaces/IRoles.sol";

/**
 * @title RolesHandler
 * @dev An abstract contract for handling roles and permissions.
 */
abstract contract RolesHandler {
    /// @notice holds Roles instance address
    IRoles public roles;

    /**
     * @dev Modifier to check if an address has the owner role.
     * @param account The address to check.
     */
    modifier onlyOwnerRole(address account) {
        require(
            roles.hasRole(roles.OWNER_ROLE(), account),
            "RolesHandler: Owner role is needed for this action"
        );
        _;
    }

    /**
     * @dev Modifier to check if an address has the manager role.
     * @param account The address to check.
     */
    modifier onlyManagerRole(address account) {
        require(
            roles.hasRole(roles.MANAGER_ROLE(), account),
            "RolesHandler: Manager role is needed for this action"
        );
        _;
    }

    /**
     * @dev Modifier to check if an address has the validator role.
     * @param account The address to check.
     */
    modifier onlyValidatorRole(address account) {
        require(
            roles.hasRole(roles.VALIDATOR_ROLE(), account),
            "RolesHandler: Validator role is needed for this action"
        );
        _;
    }

    /**
     * @dev Initializes the roles contract.
     * @param rolesAddress The address of the roles contract to be initialized.
     */
    function initRoles(address rolesAddress) external {
        require(
            address(roles) == address(0),
            "RolesHandler: roles already initialiazed"
        );
        roles = IRoles(rolesAddress);
    }
}
