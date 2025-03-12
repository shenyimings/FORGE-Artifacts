// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../metatx/interfaces/IForwarderRegistry.sol";
import {CheckpointsStorage} from "./../../lifecycle/libraries/CheckpointsStorage.sol";
import {Checkpoints} from "./../../lifecycle/Checkpoints.sol";
import {ContractOwnership} from "./../../access/ContractOwnership.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ForwarderRegistryContextBase} from "./../../metatx/base/ForwarderRegistryContextBase.sol";
import {ForwarderRegistryContext} from "./../../metatx/ForwarderRegistryContext.sol";

contract CheckpointsMock is Checkpoints, ForwarderRegistryContext {
    using CheckpointsStorage for CheckpointsStorage.Layout;

    bytes32 public constant START_CHECKPOINTID = "START";

    constructor(IForwarderRegistry forwarderRegistry) Checkpoints() ContractOwnership(msg.sender) ForwarderRegistryContext(forwarderRegistry) {}

    function enforceCheckpointReached(bytes32 checkpointId) external view {
        CheckpointsStorage.layout().enforceCheckpointReached(checkpointId);
    }

    function enforceCheckpointNotReached(bytes32 checkpointId) external view {
        CheckpointsStorage.layout().enforceCheckpointNotReached(checkpointId);
    }

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgSender() internal view virtual override(Context, ForwarderRegistryContextBase) returns (address) {
        return ForwarderRegistryContextBase._msgSender();
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgData() internal view virtual override(Context, ForwarderRegistryContextBase) returns (bytes calldata) {
        return ForwarderRegistryContextBase._msgData();
    }
}
