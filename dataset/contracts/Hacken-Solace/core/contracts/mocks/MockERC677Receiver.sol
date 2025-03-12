// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "./../interfaces/ITransferReceiver.sol";
import "./../interfaces/IApprovalReceiver.sol";

/**
 * @title Mock ERC-677 Receiver
 * @author solace.fi
 * @notice A mock contract that receives notice of token events per the [`ERC-677` standard](https://github.com/ethereum/EIPs/issues/677).
 */
contract MockERC677Receiver is ITransferReceiver, IApprovalReceiver {

    /// @notice Emitted when tokens are transferred.
    event TokenTransferred(address from, uint256 amount, bytes data);
    /// @notice Emitted when tokens are approved.
    event TokenApproved(address from, uint256 amount, bytes data);

    /**
     * @notice Called by the token contract after tokens are transferred from another account to this contract.
     * @param from The token sender.
     * @param amount The amount of tokens transferred.
     * @param data Free form calldata.
     * @return success True if the execution was successful.
     */
    function onTokenTransfer(address from, uint256 amount, bytes calldata data) external override returns (bool success) {
        emit TokenTransferred(from, amount, data);
        return true;
    }

    /**
     * @notice Called by the token contract after tokens are approved from another account to this contract.
     * @param from The token sender.
     * @param amount The amount of tokens approved.
     * @param data Free form calldata.
     * @return success True if the execution was successful.
     */
    function onTokenApproval(address from, uint256 amount, bytes calldata data) external override returns (bool success) {
        emit TokenTransferred(from, amount, data);
        return true;
    }
}
