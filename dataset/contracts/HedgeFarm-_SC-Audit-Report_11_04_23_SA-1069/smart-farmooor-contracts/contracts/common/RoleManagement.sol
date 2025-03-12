// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/utils/structs/EnumerableSetUpgradeable.sol";

abstract contract RoleManagement is AccessControlEnumerableUpgradeable {

    /// @dev Manager role - Manager of the strategy
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    /// @dev Panicooor role
    bytes32 public constant PANICOOOR_ROLE = keccak256("PANICOOOR_ROLE");
    bytes32 public constant PRIVATE_ACCESS_ROLE = keccak256("PRIVATE_ACCESS_ROLE");

    /// @dev Can be only set up once during the initialization (safety so public deployment cen never be switched to private)
    bool public isPrivateAccess;

    /// @dev Reserved storage space to allow for layout changes in the future
    uint256[50] private ______gap;

    modifier onlyRoleOrOpen(bytes32 role) {
        if (isPrivateAccess) {
            _checkRole(role, _msgSender());
        }
        _;
    }

    /// @inheritdoc AccessControlUpgradeable
    function grantRole(bytes32 role, address account) public virtual override(AccessControlUpgradeable, IAccessControlUpgradeable) onlyRole(getRoleAdmin(role)) {
        require(!(PRIVATE_ACCESS_ROLE == role && !isPrivateAccess), "PRIVATE_ACCESS_ROLE not allowed in public deployment");
        _grantRole(role, account);
    }

    /// @inheritdoc AccessControlUpgradeable
    function revokeRole(bytes32 role, address account) public virtual override(AccessControlUpgradeable, IAccessControlUpgradeable) onlyRole(getRoleAdmin(role)) {
        require(!(PRIVATE_ACCESS_ROLE == role && !isPrivateAccess), "PRIVATE_ACCESS_ROLE not allowed in public deployment");
        _revokeRole(role, account);
    }

    /**
     * @dev Return a copy of roleMember array containing all accounts with given role
     * @param role role hash
     */
    function roleAccounts(bytes32 role) public view returns (address[] memory) {
        address[] memory members = new address[](getRoleMemberCount(role));
        for(uint i = 0; i < members.length; i++) {
            members[i] = getRoleMember(role, i);        
        }
        return members;
    }

    /**
     * @dev Setup access to given accounts (used in private deployment mode)
     * @param _privateAccessAccounts list of addresses that will be granted private access role
     */
    function _setPrivateRoles(address[] memory _privateAccessAccounts) internal {
        if(_privateAccessAccounts.length == 0) {
            isPrivateAccess = false;
        } else {
            isPrivateAccess = true;
            for(uint i = 0; i < _privateAccessAccounts.length; i++) {
                _grantRole(PRIVATE_ACCESS_ROLE, _privateAccessAccounts[i]);
            }
            // account with MANAGER_ROLE can modify private access list 
            _setRoleAdmin(PRIVATE_ACCESS_ROLE, MANAGER_ROLE);
        }
    }

}
