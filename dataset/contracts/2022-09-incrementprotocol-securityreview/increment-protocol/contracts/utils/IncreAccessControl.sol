// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

// contracts
import {AccessControl} from "../../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

// interfaces
import {IIncreAccessControl} from "../interfaces/IIncreAccessControl.sol";

/// @notice Increment access control contract.
contract IncreAccessControl is AccessControl {
    bytes32 public constant GOVERNANCE = keccak256("GOVERNANCE");
    bytes32 public constant EMERGENCY_ADMIN = keccak256("EMERGENCY_ADMIN");

    constructor() {
        _setupRole(GOVERNANCE, msg.sender);
        _setRoleAdmin(GOVERNANCE, GOVERNANCE);

        _setupRole(EMERGENCY_ADMIN, msg.sender);
        _setRoleAdmin(EMERGENCY_ADMIN, GOVERNANCE);
    }

    // utils
    function isGovernor(address account) external view returns (bool) {
        return hasRole(GOVERNANCE, account);
    }

    function isEmergencyAdmin(address account) external view returns (bool) {
        return hasRole(EMERGENCY_ADMIN, account);
    }
}
