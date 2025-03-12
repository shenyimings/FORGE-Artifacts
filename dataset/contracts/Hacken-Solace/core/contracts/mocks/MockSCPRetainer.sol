// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "../interfaces/payment/ISCPRetainer.sol";

/**
 * @title Mock Solace Cover Points Retainer
 * @author solace.fi
 * @notice An implementation of SCPRetainer built for testing.
 */
contract MockSCPRetainer is ISCPRetainer {

    mapping(address => uint256) private _req;

    /**
     * @notice Sets the minimum amount of Solace Cover Points required by this contract for the account to hold.
     * @param account Account to query.
     * @param amount The amount of SCP the account must hold.
     */
    function setMinScpRequired(address account, uint256 amount) external {
        _req[account] = amount;
    }

    /**
     * @notice Calculates the minimum amount of Solace Cover Points required by this contract for the account to hold.
     * @param account Account to query.
     * @return amount The amount of SCP the account must hold.
     */
    function minScpRequired(address account) external view override returns (uint256 amount) {
        return _req[account];
    }
}
