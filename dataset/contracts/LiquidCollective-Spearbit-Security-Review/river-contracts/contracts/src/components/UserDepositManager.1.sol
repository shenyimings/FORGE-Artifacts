//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../libraries/Errors.sol";

import "../interfaces/components/IUserDepositManager.1.sol";

/// @title User Deposit Manager (v1)
/// @author Kiln
/// @notice This contract handles the inbound transfers cases or the explicit submissions
abstract contract UserDepositManagerV1 is IUserDepositManagerV1 {
    /// @notice Handler called whenever a user has sent funds to the contract
    /// @dev Must be overriden
    /// @param _depositor Address that made the deposit
    /// @param _recipient Address that receives the minted shares
    /// @param _amount Amount deposited
    function _onDeposit(address _depositor, address _recipient, uint256 _amount) internal virtual;

    /// @notice Internal utility calling the deposit handler and emitting the deposit details
    function _deposit(address _recipient) internal {
        if (msg.value == 0) {
            revert EmptyDeposit();
        }

        _onDeposit(msg.sender, _recipient, msg.value);

        emit UserDeposit(msg.sender, _recipient, msg.value);
    }

    /// @notice Returns the amount of pending ETH
    function getPendingEth() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Explicit deposit method to mint on msg.sender
    function deposit() external payable {
        _deposit(msg.sender);
    }

    /// @notice Explicit deposit method to mint on msg.sender and transfer to _recipient
    /// @param _recipient Address receiving the minted lsETH
    function depositAndTransfer(address _recipient) external payable {
        _deposit(_recipient);
    }

    /// @notice Implicit deposit method, when the user performs a regular transfer to the contract
    receive() external payable {
        _deposit(msg.sender);
    }

    /// @notice Invalid call, when the user sends a transaction with a data payload but no method matched
    fallback() external payable {
        revert Errors.InvalidCall();
    }
}
