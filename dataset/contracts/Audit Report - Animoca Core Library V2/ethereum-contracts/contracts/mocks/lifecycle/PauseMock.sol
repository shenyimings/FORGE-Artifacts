// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../metatx/interfaces/IForwarderRegistry.sol";
import {PauseStorage} from "./../../lifecycle/libraries/PauseStorage.sol";
import {Pause} from "./../../lifecycle/Pause.sol";
import {ContractOwnership} from "./../../access/ContractOwnership.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ForwarderRegistryContextBase} from "./../../metatx/base/ForwarderRegistryContextBase.sol";
import {ForwarderRegistryContext} from "./../../metatx/ForwarderRegistryContext.sol";

contract PauseMock is Pause, ForwarderRegistryContext {
    using PauseStorage for PauseStorage.Layout;

    constructor(
        bool isPaused,
        IForwarderRegistry forwarderRegistry
    ) Pause(isPaused) ContractOwnership(msg.sender) ForwarderRegistryContext(forwarderRegistry) {}

    function enforceIsPaused() external view {
        PauseStorage.layout().enforceIsPaused();
    }

    function enforceIsNotPaused() external view {
        PauseStorage.layout().enforceIsNotPaused();
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
