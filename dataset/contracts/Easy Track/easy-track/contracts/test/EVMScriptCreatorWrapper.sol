// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "../libraries/EVMScriptCreator.sol";

/// @author psirex
/// @notice Helper contract to test internal methods of EVMScriptCreator library
library EVMScriptCreatorWrapper {
    bytes4 private constant SPEC_ID = hex"00000001";

    function createEVMScript(
        address _to,
        bytes4 _methodId,
        bytes memory _evmScriptCallData
    ) external pure returns (bytes memory _commands) {
        return EVMScriptCreator.createEVMScript(_to, _methodId, _evmScriptCallData);
    }

    function createEVMScript(
        address _to,
        bytes4 _methodId,
        bytes[] memory _evmScriptCallData
    ) external pure returns (bytes memory _evmScript) {
        return EVMScriptCreator.createEVMScript(_to, _methodId, _evmScriptCallData);
    }
}
