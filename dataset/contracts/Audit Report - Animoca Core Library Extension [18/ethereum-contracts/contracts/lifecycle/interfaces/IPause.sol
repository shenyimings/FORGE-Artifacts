// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IPauseEvents} from "./../events/IPauseEvents.sol";

/// @title Pausing mechanism (functions)
interface IPause is IPauseEvents {
    /// @notice Gets the paused state of the contract.
    /// @return isPaused The paused state of the contract.
    function paused() external view returns (bool isPaused);
}
