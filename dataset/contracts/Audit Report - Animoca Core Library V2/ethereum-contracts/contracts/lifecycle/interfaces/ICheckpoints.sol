// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @title Timestamp-based checkpoints management (functions)
interface ICheckpoints {
    /// @notice Gets the checkpoint timestamp.
    /// @param checkpointId The checkpoint identifier.
    /// @return timestamp The timestamp associated to the checkpoint. A zero value indicates that the checkpoint is not set.
    function checkpoint(bytes32 checkpointId) external view returns (uint256);

    /// @notice Retrieves whether the checkpoint has been reached already.
    /// @param checkpointId The checkpoint identifier.
    /// @return reached True if the checkpoint has been set and the current block timestamp has already reached it, false otherwise.
    function checkpointReached(bytes32 checkpointId) external view returns (bool);
}
