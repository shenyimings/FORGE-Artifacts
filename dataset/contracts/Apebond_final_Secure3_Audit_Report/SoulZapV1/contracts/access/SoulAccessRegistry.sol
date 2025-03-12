// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.23;

/*
 ██████╗ █████╗ ██╗   ██╗██╗        ██████╗ █████╗ ██╗     ██╗██████╗ ██╗████████╗██╗   ██╗
██╔════╝██╔══██╗██║   ██║██║       ██╔════╝██╔══██╗██║     ██║██╔══██╗██║╚══██╔══╝╚██╗ ██╔╝
╚█████╗ ██║  ██║██║   ██║██║       ╚█████╗ ██║  ██║██║     ██║██║  ██║██║   ██║    ╚████╔╝ 
 ╚═══██╗██║  ██║██║   ██║██║        ╚═══██╗██║  ██║██║     ██║██║  ██║██║   ██║     ╚██╔╝  
██████╔╝╚█████╔╝╚██████╔╝███████╗  ██████╔╝╚█████╔╝███████╗██║██████╔╝██║   ██║      ██║   
╚═════╝  ╚════╝  ╚═════╝ ╚══════╝  ╚═════╝  ╚════╝ ╚══════╝╚═╝╚═════╝ ╚═╝   ╚═╝      ╚═╝   

 * Twitter: https://twitter.com/SoulSolidity
 *  GitHub: https://github.com/SoulSolidity
 *     Web: https://SoulSolidity.com
 */

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";

contract SoulAccessRegistry is AccessControlEnumerableUpgradeable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Mapping for role existence to prevent duplicates
    mapping(string => bool) public roleNameExists;
    // Array to keep track of all human-readable roles
    string[] private _roleNamesList;

    event RoleNameCreated(string role, bytes32 roleHash);

    error SoulAccessRegistryIndexOutOfBounds(uint256 index);

    function initialize(address _initialAdmin) external initializer {
        __AccessControlEnumerable_init();

        _grantRoleFromName("ADMIN_ROLE", _initialAdmin);
        // Setup other roles here
        // _setRoleAdminFromName("SOUL_ROLE", "ADMIN_ROLE");
    }

    /// -----------------------------------------------------------------------
    /// External functions
    /// -----------------------------------------------------------------------

    /**
     * @dev Checks if an account has a role based on the role's name.
     * @param roleName The name of the role to check.
     * @param account The address of the account to check for the role.
     * @return bool indicating whether the account has the role.
     */
    function hasRoleName(string memory roleName, address account) external view returns (bool) {
        return hasRole(keccak256(bytes(roleName)), account);
    }

    /**
     * @dev Retrieves the role name at a given index in the list of role names.
     * @param index The index in the list of role names.
     * @return The role name at the specified index.
     * @notice Reverts if the index is out of bounds.
     */
    function getRoleNameByIndex(uint256 index) public view returns (string memory) {
        if (index >= getRoleNameLength()) {
            revert SoulAccessRegistryIndexOutOfBounds(index);
        }
        return _roleNamesList[index];
    }

    /**
     * @dev Returns the total number of unique role names stored by the contract.
     * @return The total number of unique role names.
     */
    function getRoleNameLength() public view returns (uint256) {
        return _roleNamesList.length;
    }

    /**
     * @dev Grants a role to an account based on the role's name.
     * @param roleName The name of the role to grant.
     * @param account The address of the account to grant the role to.
     * @notice The caller must have the admin role for the role being granted.
     */
    function grantRoleName(
        string memory roleName,
        address account
    ) external onlyRole(getRoleAdmin(_getRoleHash(roleName))) {
        _grantRoleFromName(roleName, account);
    }

    /**
     * @dev Sets the admin role for a specific role by name.
     * @param roleName The name of the role to set the admin role for.
     * @param adminRoleName The name of the admin role to set.
     * @notice The caller must have the ADMIN_ROLE to call this function.
     */
    function setRoleAdminByName(string memory roleName, string memory adminRoleName) external onlyRole(ADMIN_ROLE) {
        _setRoleAdminFromName(roleName, adminRoleName);
    }

    /// -----------------------------------------------------------------------
    /// Internal/Private functions
    /// -----------------------------------------------------------------------

    function _setRoleAdminFromName(string memory roleName, string memory adminRoleName) internal {
        _setRoleAdmin(_createRoleName(roleName), _createRoleName(adminRoleName));
    }

    function _grantRoleFromName(string memory roleName, address account) internal {
        _grantRole(_createRoleName(roleName), account);
    }

    function _createRoleName(string memory role) internal returns (bytes32 roleHash) {
        roleHash = _getRoleHash(role);
        if (!roleNameExists[role]) {
            _roleNamesList.push(role);
            roleNameExists[role] = true;
            emit RoleNameCreated(role, roleHash);
        }
    }

    function _getRoleHash(string memory role) private pure returns (bytes32) {
        return keccak256(bytes(role));
    }
}
