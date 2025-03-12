// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @title Timestamp-based checkpoints management (events)
interface ICheckpointsEvents {
    /// @notice Emitted when a checkpoint is set.
    /// @param checkpointId The checkpoint identifier.
    /// @param timestamp The timestamp associated to the checkpoint.
    event CheckpointSet(bytes32 checkpointId, uint256 timestamp);

    /// @notice Gets the checkpoint timestamp.
    /// @param checkpointId The checkpoint identifier.
    /// @return timestamp The timestamp associated to the checkpoint. A zero value indicates that the checkpoint is not set.
    function checkpoint(bytes32 checkpointId) external view returns (uint256);
}
