// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {NotRoleHolder, NotTargetContractRoleHolder} from "./../errors/AccessControlErrors.sol";
import {TargetIsNotAContract} from "./../errors/Common.sol";
import {IAccessControlEvents} from "./../events/IAccessControlEvents.sol";
import {IAccessControl} from "./../interfaces/IAccessControl.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

library AccessControlStorage {
    using Address for address;
    using AccessControlStorage for AccessControlStorage.Layout;

    struct Layout {
        mapping(bytes32 => mapping(address => bool)) roles;
    }

    bytes32 internal constant LAYOUT_STORAGE_SLOT = bytes32(uint256(keccak256("animoca.core.access.AccessControl.storage")) - 1);

    /// @notice Grants a role to an account.
    /// @dev Note: Call to this function should be properly access controlled.
    /// @dev Emits a {RoleGranted} event if the account did not previously have the role.
    /// @param role The role to grant.
    /// @param account The account to grant the role to.
    /// @param operator The account requesting the role change.
    function grantRole(Layout storage s, bytes32 role, address account, address operator) internal {
        if (!s.hasRole(role, account)) {
            s.roles[role][account] = true;
            emit IAccessControlEvents.RoleGranted(role, account, operator);
        }
    }

    /// @notice Revokes a role from an account.
    /// @dev Note: Call to this function should be properly access controlled.
    /// @dev Emits a {RoleRevoked} event if the account previously had the role.
    /// @param role The role to revoke.
    /// @param account The account to revoke the role from.
    /// @param operator The account requesting the role change.
    function revokeRole(Layout storage s, bytes32 role, address account, address operator) internal {
        if (s.hasRole(role, account)) {
            s.roles[role][account] = false;
            emit IAccessControlEvents.RoleRevoked(role, account, operator);
        }
    }

    /// @notice Renounces a role by the sender.
    /// @dev Reverts with {NotRoleHolder} if `sender` does not have `role`.
    /// @dev Emits a {RoleRevoked} event.
    /// @param sender The message sender.
    /// @param role The role to renounce.
    function renounceRole(Layout storage s, address sender, bytes32 role) internal {
        s.enforceHasRole(role, sender);
        s.roles[role][sender] = false;
        emit IAccessControlEvents.RoleRevoked(role, sender, sender);
    }

    /// @notice Retrieves whether an account has a role.
    /// @param role The role.
    /// @param account The account.
    /// @return hasRole_ Whether `account` has `role`.
    function hasRole(Layout storage s, bytes32 role, address account) internal view returns (bool hasRole_) {
        return s.roles[role][account];
    }

    /// @notice Checks whether an account has a role in a target contract.
    /// @param targetContract The contract to check.
    /// @param role The role to check.
    /// @param account The account to check.
    /// @return hasTargetContractRole_ Whether `account` has `role` in `targetContract`.
    function hasTargetContractRole(address targetContract, bytes32 role, address account) internal view returns (bool hasTargetContractRole_) {
        if (!targetContract.isContract()) revert TargetIsNotAContract(targetContract);
        return IAccessControl(targetContract).hasRole(role, account);
    }

    /// @notice Ensures that an account has a role.
    /// @dev Reverts with {NotRoleHolder} if `account` does not have `role`.
    /// @param role The role.
    /// @param account The account.
    function enforceHasRole(Layout storage s, bytes32 role, address account) internal view {
        if (!s.hasRole(role, account)) revert NotRoleHolder(role, account);
    }

    /// @notice Enforces that an account has a role in a target contract.
    /// @dev Reverts with {NotTargetContractRoleHolder} if the account does not have the role.
    /// @param targetContract The contract to check.
    /// @param role The role to check.
    /// @param account The account to check.
    function enforceHasTargetContractRole(address targetContract, bytes32 role, address account) internal view {
        if (!hasTargetContractRole(targetContract, role, account)) revert NotTargetContractRoleHolder(targetContract, role, account);
    }

    function layout() internal pure returns (Layout storage s) {
        bytes32 position = LAYOUT_STORAGE_SLOT;
        assembly {
            s.slot := position
        }
    }
}
