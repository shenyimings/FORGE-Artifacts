// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;


/**
 * @title IApprovalReceiver
 * @author solace.fi
 * @notice An interface that receives notice of token approval events per the [`ERC-677` standard](https://github.com/ethereum/EIPs/issues/677).
 */
interface IApprovalReceiver {

    /**
     * @notice Called by the token contract after tokens are approved from another account to this contract.
     * @param from The token sender.
     * @param amount The amount of tokens approved.
     * @param data Free form calldata.
     * @return success True if the execution was successful.
     */
    function onTokenApproval(address from, uint256 amount, bytes calldata data) external returns (bool success);
}
