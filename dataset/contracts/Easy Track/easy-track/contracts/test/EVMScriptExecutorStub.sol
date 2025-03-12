// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

/// @author psirex
/// @notice Helper contract to stub EVMScriptExecutor
contract EVMScriptExecutorStub {
    bytes public evmScript;

    function executeEVMScript(bytes memory _evmScript) external returns (bytes memory) {
        evmScript = _evmScript;
    }
}
