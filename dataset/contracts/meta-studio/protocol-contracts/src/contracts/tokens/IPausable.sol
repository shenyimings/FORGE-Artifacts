// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

/// @title Interface "Pausable"
/// @dev declaration of IPausable methods
interface IPausable {
    /// @notice check if a contract is in `Pause` state
    /// @return true if the contract is in `Pause` otherwise false
    function paused() external view returns (bool);

    /// @notice Set the contract in pause. No transfer is allowed
    function pause() external;

    /// @notice Set the contract in ready state. Transfers are allowed
    function unpause() external;
}
