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

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ISoulAccessManaged} from "./ISoulAccessManaged.sol";

contract SoulAccessManaged is ISoulAccessManaged {
    address public soulAccessRegistry;

    error SoulAccessUnauthorized();

    constructor(address _accessRegistryAddress) {
        soulAccessRegistry = _accessRegistryAddress;
    }

    /**
     * @dev Modifier to make a function callable only by accounts with a specific role in the SoulAccessRegistry.
     * @param roleName The name of the role to check.
     * Reverts with a SoulAccessUnauthorizedAccount error if the calling account does not have the role.
     */
    modifier onlyAccessRegistryRoleName(string memory roleName) {
        if (!_hasAccessRegistryRole(_getRoleHash(roleName), msg.sender)) {
            revert SoulAccessUnauthorized();
        }
        _;
    }

    /**
     * @dev Modifier to make a function callable only by accounts with a specific role in the SoulAccessRegistry.
     * @param role The hash of the role to check.
     * Reverts with a SoulAccessUnauthorizedAccount error if the calling account does not have the role.
     */
    modifier onlyAccessRegistryRole(bytes32 role) {
        if (!_hasAccessRegistryRole(role, msg.sender)) {
            revert SoulAccessUnauthorized();
        }
        _;
    }

    /**
     * @dev Generates a hash for a role name to be used within the SoulAccessRegistry.
     * @param role The name of the role.
     * @return bytes32 The hash of the role name.
     */
    function _getRoleHash(string memory role) internal pure returns (bytes32) {
        return keccak256(bytes(role));
    }

    /**
     * @dev Checks if an account has a specific role in the SoulAccessRegistry.
     * @param role The hash of the role to check.
     * @param account The address of the account to check.
     * @return bool True if the account has the role, false otherwise.
     */
    function _hasAccessRegistryRole(bytes32 role, address account) private view returns (bool) {
        return IAccessControl(soulAccessRegistry).hasRole(role, account);
    }
}
