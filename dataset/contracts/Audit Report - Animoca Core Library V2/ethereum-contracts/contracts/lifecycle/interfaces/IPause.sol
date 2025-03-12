// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @title Pausing mechanism (functions)
interface IPause {
    /// @notice Gets the paused state of the contract.
    /// @return isPaused The paused state of the contract.
    function paused() external view returns (bool isPaused);
}
