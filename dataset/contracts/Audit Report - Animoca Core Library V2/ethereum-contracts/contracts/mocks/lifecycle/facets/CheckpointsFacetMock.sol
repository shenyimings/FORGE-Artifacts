// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../metatx/interfaces/IForwarderRegistry.sol";
import {CheckpointsStorage} from "./../../../lifecycle/libraries/CheckpointsStorage.sol";
import {CheckpointsFacet} from "./../../../lifecycle/facets/CheckpointsFacet.sol";

contract CheckpointsFacetMock is CheckpointsFacet {
    using CheckpointsStorage for CheckpointsStorage.Layout;

    bytes32 public constant START_CHECKPOINTID = "START";

    constructor(IForwarderRegistry forwarderRegistry) CheckpointsFacet(forwarderRegistry) {}

    function enforceCheckpointReached(bytes32 checkpointId) external view {
        CheckpointsStorage.layout().enforceCheckpointReached(checkpointId);
    }

    function enforceCheckpointNotReached(bytes32 checkpointId) external view {
        CheckpointsStorage.layout().enforceCheckpointNotReached(checkpointId);
    }

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
