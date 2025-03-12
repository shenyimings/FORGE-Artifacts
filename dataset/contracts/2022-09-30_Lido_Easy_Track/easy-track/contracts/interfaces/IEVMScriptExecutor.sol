// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

/// @notice Interface of EVMScript executor used by EasyTrack
interface IEVMScriptExecutor {
    function executeEVMScript(bytes memory _evmScript) external returns (bytes memory);
}
