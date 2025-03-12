// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.18;

import "./CallWhitelist.sol";
import "./CallWhitelistDelegation.sol";
import "./CallWhitelistApprovals.sol";

/**
 * @title CallWhitelistAllExtensions
 * @author Non-Fungible Technologies, Inc.
 *
 * CallWhitelist with both the approvals and delegation extension.
 * See CallWhitelist, CallWhitelistApprovals, and CallWhitelistDelegation
 * contract descriptions for more information.
 */
contract CallWhitelistAllExtensions is CallWhitelist, CallWhitelistApprovals, CallWhitelistDelegation {

    /// @dev Deploys the contracts with the needed inherited behavior.
    constructor(address _registry) CallWhitelistDelegation(_registry) {}
}
