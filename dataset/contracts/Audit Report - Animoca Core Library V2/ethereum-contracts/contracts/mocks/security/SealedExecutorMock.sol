// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../metatx/interfaces/IForwarderRegistry.sol";
import {SealedExecutor} from "./../../security/SealedExecutor.sol";

contract SealedExecutorMock is SealedExecutor {
    constructor(IForwarderRegistry forwarderRegistry) SealedExecutor(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
