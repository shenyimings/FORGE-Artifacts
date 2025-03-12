// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { RoleToUsers } from "../Common.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

// Manages sensitive parameters of the strategy for example fee swap service.
// Any parameter change that can result in stolen or lost funds should be managed by the governor role.
// keccak256("GOVERNOR_ROLE")
bytes32 constant GOVERNOR_ROLE = 0x7935bd0ae54bc31f548c14dba4d37c5c64b3f8ca900cb468fb8abd54d5894f55;

// Manages less sensitive parameters of the strategy for example setting investment limits.
// keccak256("STRATEGIST_ROLE")
bytes32 constant STRATEGIST_ROLE = 0x17a8e30262c1f919c33056d877a3c22b95c2f5e4dac44683c1c2323cd79fbdb0;

// Manages routine, periodic tasks like delta neutral rebalancing and liquidation protection.
// keccak256("MAINTAINER_ROLE")
bytes32 constant MAINTAINER_ROLE = 0x339759585899103d2ace64958e37e18ccb0504652c81d4a1b8aa80fe2126ab95;

// Manages smart contract upgrades.
// keccak256("UPGRADE_ROLE")
bytes32 constant UPGRADE_ROLE = 0x88aa719609f728b0c5e7fb8dd3608d5c25d497efbb3b9dd64e9251ebba101508;

// Manages smart contract pausability.
// keccak256("PAUSE_ROLE")
bytes32 constant PAUSE_ROLE = 0x139c2898040ef16910dc9f44dc697df79363da767d8bc92f2e310312b816e46d;

// Manages role memberships for all roles including the ADMIN_ROLE.
bytes32 constant ADMIN_ROLE = 0x0;

abstract contract RoleableUpgradeable is AccessControlEnumerableUpgradeable {
    error MissingAdminRole();

    // solhint-disable-next-line
    function __RoleableBaseUpgradeable_init(RoleToUsers[] calldata roleToUsers)
        internal
        onlyInitializing
    {
        __AccessControlEnumerable_init();

        uint256 roleToUsersArrayLength = roleToUsers.length;
        bool hasAdminRole = false;
        for (uint256 i = 0; i < roleToUsersArrayLength; i++) {
            uint256 roleToUsersLength = roleToUsers[i].users.length;
            for (uint256 j = 0; j < roleToUsersLength; j++) {
                if (roleToUsers[i].role == ADMIN_ROLE) hasAdminRole = true;

                _grantRole(roleToUsers[i].role, roleToUsers[i].users[j]);
            }
        }
        if (!hasAdminRole) revert MissingAdminRole();
    }
}
