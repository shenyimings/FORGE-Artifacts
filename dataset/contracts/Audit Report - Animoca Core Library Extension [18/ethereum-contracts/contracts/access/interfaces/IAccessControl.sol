// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IAccessControlEvents} from "./../events/IAccessControlEvents.sol";

/// @title Access control via roles management (functions)
interface IAccessControl is IAccessControlEvents {
    /// @notice Renounces a role by the sender.
    /// @dev Reverts if `sender` does not have `role`.
    /// @dev Emits a {RoleRevoked} event.
    /// @param role The role to renounce.
    function renounceRole(bytes32 role) external;

    /// @notice Retrieves whether an account has a role.
    /// @param role The role.
    /// @param account The account.
    /// @return hasRole_ Whether `account` has `role`.
    function hasRole(bytes32 role, address account) external view returns (bool hasRole_);
}
