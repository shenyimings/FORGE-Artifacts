// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @title Pausing mechanism (events)
interface IPauseEvents {
    /// @notice Emitted when the pause is triggered.
    event Paused();

    /// @notice Emitted when the pause is lifted.
    event Unpaused();
}
