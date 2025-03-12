// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @notice Thrown when trying to set a checkpoint which is already set.
/// @param checkpointId The checkpoint identifier.
error CheckpointAlreadySet(bytes32 checkpointId);

/// @notice Thrown when a checkpoint has not been reached yet but is required to.
/// @param checkpointId The checkpoint identifier.
error CheckpointNotReached(bytes32 checkpointId);

/// @notice Thrown when a checkpoint has already been reached but is required not to.
/// @param checkpointId The checkpoint identifier.
error CheckpointReached(bytes32 checkpointId);
