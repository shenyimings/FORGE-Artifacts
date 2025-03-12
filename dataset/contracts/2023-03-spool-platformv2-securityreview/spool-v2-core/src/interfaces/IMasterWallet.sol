// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/token/ERC20/IERC20.sol";

interface IMasterWallet {
    /**
     * @notice Approves the amount of token the spender can use.
     * @dev Requirements:
     * - caller must have role ROLE_MASTER_WALLET_MANAGER
     * @param token Token on which to make the approval.
     * @param spender Address that is approved.
     * @param amount Amount of tokens to approve.
     */
    function approve(IERC20 token, address spender, uint256 amount) external;

    /**
     * @notice Resets the approval on token for spender back to 0.
     * @dev Requirements:
     * - caller must have role ROLE_MASTER_WALLET_MANAGER
     * @param token Token on which to reset the approval.
     * @param spender Address for which to reset the approval.
     */
    function resetApprove(IERC20 token, address spender) external;

    /**
     * @notice Transfers amount of token to the recipient.
     * @dev Requirements:
     * - caller must have role ROLE_MASTER_WALLET_MANAGER
     * @param token Token to transfer.
     * @param recipient Target of the transfer.
     * @param amount Amount to transfer.
     */
    function transfer(IERC20 token, address recipient, uint256 amount) external;
}
