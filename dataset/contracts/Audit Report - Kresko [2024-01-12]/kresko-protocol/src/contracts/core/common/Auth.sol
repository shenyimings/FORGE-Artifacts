// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Strings} from "libs/Strings.sol";
import {EnumerableSet} from "libs/EnumerableSet.sol";
import {Meta} from "libs/Meta.sol";
import {ds} from "diamond/DState.sol";

import {Errors} from "common/Errors.sol";
import {Role} from "common/Constants.sol";
import {cs} from "common/State.sol";

interface IGnosisSafeL2 {
    function isOwner(address owner) external view returns (bool);

    function getOwners() external view returns (address[] memory);
}

/**
 * @title Shared library for access control
 * @author Kresko
 */
library Auth {
    using EnumerableSet for EnumerableSet.AddressSet;
    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /* -------------------------------------------------------------------------- */
    /*                                Functionality                               */
    /* -------------------------------------------------------------------------- */

    function hasRole(bytes32 role, address account) internal view returns (bool) {
        return cs()._roles[role].members[account];
    }

    function getRoleMemberCount(bytes32 role) internal view returns (uint256) {
        return cs()._roleMembers[role].length();
    }

    /**
     * @dev Revert with a standard message if `msg.sender` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function checkRole(bytes32 role) internal view {
        _checkRole(role, msg.sender);
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) internal view returns (bytes32) {
        return cs()._roles[role].adminRole;
    }

    function getRoleMember(bytes32 role, uint256 index) internal view returns (address) {
        return cs()._roleMembers[role].at(index);
    }

    /**
     * @notice setups the security council
     *
     */
    function setupSecurityCouncil(address _councilAddress) internal {
        if (getRoleMemberCount(Role.SAFETY_COUNCIL) != 0)
            revert Errors.SAFETY_COUNCIL_ALREADY_EXISTS(_councilAddress, getRoleMember(Role.SAFETY_COUNCIL, 0));
        if (!IGnosisSafeL2(_councilAddress).isOwner(ds().contractOwner))
            revert Errors.SAFETY_COUNCIL_SETTER_IS_NOT_ITS_OWNER(_councilAddress);

        cs()._roles[Role.SAFETY_COUNCIL].members[_councilAddress] = true;
        cs()._roleMembers[Role.SAFETY_COUNCIL].add(_councilAddress);

        emit RoleGranted(Role.SAFETY_COUNCIL, _councilAddress, msg.sender);
    }

    function transferSecurityCouncil(address _newCouncil) internal {
        checkRole(Role.SAFETY_COUNCIL);
        uint256 owners = IGnosisSafeL2(_newCouncil).getOwners().length;
        if (owners < 5) revert Errors.MULTISIG_NOT_ENOUGH_OWNERS(_newCouncil, owners, 5);

        cs()._roles[Role.SAFETY_COUNCIL].members[msg.sender] = false;
        cs()._roleMembers[Role.SAFETY_COUNCIL].remove(msg.sender);

        cs()._roles[Role.SAFETY_COUNCIL].members[_newCouncil] = true;
        cs()._roleMembers[Role.SAFETY_COUNCIL].add(_newCouncil);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) internal {
        checkRole(getRoleAdmin(role));
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) internal {
        checkRole(getRoleAdmin(role));
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function _renounceRole(bytes32 role, address account) internal {
        if (account != msg.sender) revert Errors.ACCESS_CONTROL_NOT_SELF(account, msg.sender);

        _revokeRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        bytes32 previousAdminRole = getRoleAdmin(role);
        cs()._roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * @notice Cannot grant the role `SAFETY_COUNCIL` - must be done via explicit function.
     *
     * Internal function without access restriction.
     */
    function _grantRole(bytes32 role, address account) internal ensureNotSafetyCouncil(role) {
        if (!hasRole(role, account)) {
            cs()._roles[role].members[account] = true;
            cs()._roleMembers[role].add(account);
            emit RoleGranted(role, account, msg.sender);
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     */
    function _revokeRole(bytes32 role, address account) internal {
        if (hasRole(role, account)) {
            cs()._roles[role].members[account] = false;
            cs()._roleMembers[role].remove(account);
            emit RoleRevoked(role, account, Meta.msgSender());
        }
    }

    /**
     * @dev Ensure we use the explicit `grantSafetyCouncilRole` function.
     */
    modifier ensureNotSafetyCouncil(bytes32 role) {
        if (role == Role.SAFETY_COUNCIL) revert Errors.SAFETY_COUNCIL_NOT_ALLOWED();
        _;
    }
}
