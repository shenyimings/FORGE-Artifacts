// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Ingest Master Proxy Contract
 * @author Origin Protocol Inc
 */

import {
    GovernedUpgradeabilityProxy
} from "../governance/GovernedUpgradeabilityProxy.sol";

/**
 * @notice IngestMatery
 */
contract IngestMasterProxy is GovernedUpgradeabilityProxy {
    constructor(address _logic) GovernedUpgradeabilityProxy(_logic, "") {}
}
