// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import {IGnosisSafeL2} from "../vendor/gnosis/IGnosisSafeL2.sol";
import {Strings} from "./Strings.sol";
import {AuthEvent} from "./Events.sol";
import {EnumerableSet} from "./EnumerableSet.sol";
import {Error} from "./Errors.sol";
import {Meta} from "./Meta.sol";
import {ds} from "../diamond/DiamondStorage.sol";

/* solhint-disable state-visibility */

/**
 * @title Shared library for access control
 * @author Kresko
 */

/* -------------------------------------------------------------------------- */
/*                                    Roles                                   */
/* -------------------------------------------------------------------------- */

library Role {
    /// @dev role that grants other roles
    bytes32 constant DEFAULT_ADMIN = 0x00;
    /// @dev  keccak256("kresko.roles.minter.admin")
    bytes32 constant ADMIN = 0xb9dacdf02281f2e98ddbadaaf44db270b3d5a916342df47c59f77937a6bcd5d8;
    /// @dev keccak256("kresko.roles.minter.operator")
    bytes32 constant OPERATOR = 0x112e48a576fb3a75acc75d9fcf6e0bc670b27b1dbcd2463502e10e68cf57d6fd;
    /// @dev keccak256("kresko.roles.minter.manager")
    bytes32 constant MANAGER = 0x46925e0f0cc76e485772167edccb8dc449d43b23b55fc4e756b063f49099e6a0;
    /// @dev keccak256("kresko.roles.minter.safety.council")
    bytes32 constant SAFETY_COUNCIL = 0x9c387ecf1663f9144595993e2c602b45de94bf8ba3a110cb30e3652d79b581c0;
}

library Authorization {
    using EnumerableSet for EnumerableSet.AddressSet;

    function hasRole(bytes32 role, address account) internal view returns (bool) {
        return ds()._roles[role].members[account];
    }

    function getRoleMemberCount(bytes32 role) internal view returns (uint256) {
        return ds()._roleMembers[role].length();
    }

    /**
     * @dev Revert with a standard message if `Meta.msgSender` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function checkRole(bytes32 role) internal view {
        _checkRole(role, Meta.msgSender());
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
        return ds()._roles[role].adminRole;
    }

    function getRoleMember(bytes32 role, uint256 index) internal view returns (address) {
        return ds()._roleMembers[role].at(index);
    }

    /**
     * @notice Checks if the target contract implements the ERC165 interfaceId for the multisig.
     *
     */
    function setupSecurityCouncil(address _councilAddress) internal {
        require(getRoleMemberCount(Role.SAFETY_COUNCIL) == 0, Error.SAFETY_COUNCIL_EXISTS);
        require(IGnosisSafeL2(_councilAddress).isOwner(msg.sender), Error.ADDRESS_INVALID_SAFETY_COUNCIL);

        ds()._roles[Role.SAFETY_COUNCIL].members[_councilAddress] = true;
        ds()._roleMembers[Role.SAFETY_COUNCIL].add(_councilAddress);

        emit AuthEvent.RoleGranted(Role.SAFETY_COUNCIL, _councilAddress, Meta.msgSender());
    }

    function transferSecurityCouncil(address _newCouncil) internal {
        hasRole(Role.SAFETY_COUNCIL, msg.sender);
        require(IGnosisSafeL2(_newCouncil).getOwners().length >= 5, Error.MULTISIG_NOT_ENOUGH_OWNERS);

        // As this is called by the multisig - just check that it's not an EOA
        ds()._roles[Role.SAFETY_COUNCIL].members[msg.sender] = false;
        ds()._roleMembers[Role.SAFETY_COUNCIL].remove(msg.sender);

        ds()._roles[Role.SAFETY_COUNCIL].members[_newCouncil] = true;
        ds()._roleMembers[Role.SAFETY_COUNCIL].add(_newCouncil);
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
        ds()._roleMembers[role].remove(account);
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
        require(account == Meta.msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        bytes32 previousAdminRole = getRoleAdmin(role);
        ds()._roles[role].adminRole = adminRole;
        emit AuthEvent.RoleAdminChanged(role, previousAdminRole, adminRole);
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
            ds()._roles[role].members[account] = true;
            ds()._roleMembers[role].add(account);
            emit AuthEvent.RoleGranted(role, account, Meta.msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     */
    function _revokeRole(bytes32 role, address account) internal {
        if (hasRole(role, account)) {
            ds()._roles[role].members[account] = false;
            ds()._roleMembers[role].remove(account);
            emit AuthEvent.RoleRevoked(role, account, Meta.msgSender());
        }
    }

    /**
     * @dev Ensure we use the explicit `grantSafetyCouncilRole` function.
     */
    modifier ensureNotSafetyCouncil(bytes32 role) {
        require(role != Role.SAFETY_COUNCIL, Error.ADDRESS_INVALID_SAFETY_COUNCIL);
        _;
    }
}
