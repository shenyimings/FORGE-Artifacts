// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/

pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Strings.sol";

library LibAccessControl {
  // -------------
  //    Events
  // -------------
  event RoleAdminChanged(
    bytes32 indexed role,
    bytes32 indexed previousAdminRole,
    bytes32 indexed newAdminRole
  );
  event RoleGranted(
    bytes32 indexed role,
    address indexed account,
    address indexed sender
  );
  event RoleRevoked(
    bytes32 indexed role,
    address indexed account,
    address indexed sender
  );

  // -------------
  //    Constants
  // -------------
  // keccak256("com.alperp.accesscontrol.diamond.storage")
  bytes32 internal constant ACCESS_CONTROL_STORAGE_POSITION =
    0x2eac95ee7a1f537d7375d06e878e6e955431f9de386e0889d1d7864f91099439;

  bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
  bytes32 public constant FARM_KEEPER = keccak256("FARM_KEEPER_ROLE");

  // -------------
  //    Storage
  // -------------
  struct RoleData {
    mapping(address => bool) members;
    bytes32 adminRole;
  }
  struct AccessControlDiamondStorage {
    mapping(bytes32 => RoleData) roles;
  }

  function accessControlDiamondStorage()
    internal
    pure
    returns (AccessControlDiamondStorage storage accessControlDS)
  {
    assembly {
      accessControlDS.slot := ACCESS_CONTROL_STORAGE_POSITION
    }
  }

  /**
   * @dev Returns the admin role that controls `role`. See {grantRole} and
   * {revokeRole}.
   *
   * To change a role's admin, use {_setRoleAdmin}.
   */
  function _getRoleAdmin(bytes32 role) internal view returns (bytes32) {
    AccessControlDiamondStorage
      storage accessControlDs = accessControlDiamondStorage();
    return accessControlDs.roles[role].adminRole;
  }

  /**
   * @dev Returns `true` if `account` has been granted `role`.
   */
  function _hasRole(bytes32 role, address account)
    internal
    view
    returns (bool)
  {
    AccessControlDiamondStorage
      storage accessControlDs = accessControlDiamondStorage();
    return accessControlDs.roles[role].members[account];
  }

  /**
   * @dev Revert with a standard message if `msg.sender` is missing `role`.
   * Overriding this function changes the behavior of the {onlyRole} modifier.
   *
   * Format of the revert message is described in {_checkRole}.
   */
  function _checkRole(bytes32 role) internal view {
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
    if (!_hasRole(role, account)) {
      revert(
        string(
          abi.encodePacked(
            "AccessControl: account ",
            Strings.toHexString(account),
            " is missing role ",
            Strings.toHexString(uint256(role), 32)
          )
        )
      );
    }
  }

  /**
   * @dev Grants `role` to `account`.
   *
   * If `account` had not been already granted `role`, emits a {RoleGranted}
   * event. Note that unlike {grantRole}, this function doesn't perform any
   * checks on the calling account.
   *
   * May emit a {RoleGranted} event.
   *
   * [WARNING]
   * ====
   * This function should only be called from the constructor when setting
   * up the initial roles for the system.
   *
   * Using this function in any other way is effectively circumventing the admin
   * system imposed by {AccessControl}.
   * ====
   *
   * NOTE: This function is deprecated in favor of {_grantRole}.
   */
  function _setupRole(bytes32 role, address account) internal {
    _grantRole(role, account);
  }

  /**
   * @dev Sets `adminRole` as ``role``'s admin role.
   *
   * Emits a {RoleAdminChanged} event.
   */
  function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
    AccessControlDiamondStorage
      storage accessControlDs = accessControlDiamondStorage();
    bytes32 previousAdminRole = _getRoleAdmin(role);
    accessControlDs.roles[role].adminRole = adminRole;
    emit RoleAdminChanged(role, previousAdminRole, adminRole);
  }

  /**
   * @dev Grants `role` to `account`.
   *
   * Internal function without access restriction.
   *
   * May emit a {RoleGranted} event.
   */
  function _grantRole(bytes32 role, address account) internal {
    if (!_hasRole(role, account)) {
      AccessControlDiamondStorage
        storage accessControlDs = accessControlDiamondStorage();
      accessControlDs.roles[role].members[account] = true;
      emit RoleGranted(role, account, msg.sender);
    }
  }

  /**
   * @dev Revokes `role` from `account`.
   *
   * Internal function without access restriction.
   *
   * May emit a {RoleRevoked} event.
   */
  function _revokeRole(bytes32 role, address account) internal {
    if (_hasRole(role, account)) {
      AccessControlDiamondStorage
        storage accessControlDs = accessControlDiamondStorage();
      accessControlDs.roles[role].members[account] = false;
      emit RoleRevoked(role, account, msg.sender);
    }
  }
}
