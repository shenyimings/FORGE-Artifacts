// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @notice Emitted when a checkpoint is set.
/// @param checkpointId The checkpoint identifier.
/// @param timestamp The timestamp associated to the checkpoint.
event CheckpointSet(bytes32 checkpointId, uint256 timestamp);
