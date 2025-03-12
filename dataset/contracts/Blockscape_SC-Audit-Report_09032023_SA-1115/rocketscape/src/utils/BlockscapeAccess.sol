// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "openzeppelin-contracts/access/AccessControl.sol";

/// @title Blockscape Access
/// @notice Shared contract for Blockscape Validator and Stake ETH NFTs, used to set the access roles
/// @dev This contract is abstract and cannot be deployed
abstract contract BlockscapeAccess is AccessControl {
    /// @dev role to adjust the config of the smart contract parameters
    bytes32 internal constant ADJ_CONFIG_ROLE = keccak256("ADJ_CONFIG_ROLE");

    /// @dev role for the backendController executer
    bytes32 internal constant RP_BACKEND_ROLE = keccak256("RP_BACKEND_ROLE");

    /// @dev role to open / close vault in cases of emergencies
    bytes32 internal constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    constructor(
        address adj_config_role,
        address rp_backend_role,
        address emergency_role
    ) {
        _grantRole(ADJ_CONFIG_ROLE, adj_config_role);
        _grantRole(RP_BACKEND_ROLE, rp_backend_role);
        _grantRole(EMERGENCY_ROLE, emergency_role);
    }
}
