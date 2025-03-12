// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {IAuthorizationFacet} from "../interfaces/IAuthorizationFacet.sol";
import {Authorization, Role} from "../../libs/Authorization.sol";

/**
 * @title Enumerable access control for the EIP2535-pattern following the OZ implementation.
 * @author Kresko
 * @notice The storage area is in the main proxy diamond storage.
 * @dev Difference here is the logic library that is shared and reused, there is no state here.
 */
contract AuthorizationFacet is IAuthorizationFacet {
    using Authorization for bytes32;

    /// @inheritdoc IAuthorizationFacet
    function getRoleMember(bytes32 role, uint256 index) external view returns (address) {
        return role.getRoleMember(index);
    }

    /// @inheritdoc IAuthorizationFacet
    function getRoleMemberCount(bytes32 role) external view returns (uint256) {
        return role.getRoleMemberCount();
    }

    /// @inheritdoc IAuthorizationFacet
    function grantRole(bytes32 role, address account) external {
        role.grantRole(account);
    }

    /// @inheritdoc IAuthorizationFacet
    function revokeRole(bytes32 role, address account) external {
        role.revokeRole(account);
    }

    /// @inheritdoc IAuthorizationFacet
    function hasRole(bytes32 role, address account) external view returns (bool) {
        return role.hasRole(account);
    }

    /// @inheritdoc IAuthorizationFacet
    function getRoleAdmin(bytes32 role) external view returns (bytes32) {
        return role.getRoleAdmin();
    }

    /// @inheritdoc IAuthorizationFacet
    function renounceRole(bytes32 role, address account) external {
        role._renounceRole(account);
    }
}
