// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

/// @author psirex
/// @notice Contains methods for convenient creation
/// of EVMScripts in EVMScript factories contracts
library EVMScriptCreator {
    // Id of default CallsScript Aragon's executor.
    bytes4 private constant SPEC_ID = hex"00000001";

    /// @notice Encodes one method call as EVMScript
    function createEVMScript(
        address _to,
        bytes4 _methodId,
        bytes memory _evmScriptCallData
    ) internal pure returns (bytes memory _commands) {
        return
            abi.encodePacked(
                SPEC_ID,
                _to,
                uint32(_evmScriptCallData.length) + 4,
                _methodId,
                _evmScriptCallData
            );
    }

    /// @notice Encodes multiple calls of the same method on one contract as EVMScript
    function createEVMScript(
        address _to,
        bytes4 _methodId,
        bytes[] memory _evmScriptCallData
    ) internal pure returns (bytes memory _evmScript) {
        for (uint256 i = 0; i < _evmScriptCallData.length; ++i) {
            _evmScript = bytes.concat(
                _evmScript,
                abi.encodePacked(
                    _to,
                    uint32(_evmScriptCallData[i].length) + 4,
                    _methodId,
                    _evmScriptCallData[i]
                )
            );
        }
        _evmScript = bytes.concat(SPEC_ID, _evmScript);
    }

    /// @notice Encodes multiple calls to different methods within the same contract as EVMScript
    function createEVMScript(
        address _to,
        bytes4[] memory _methodIds,
        bytes[] memory _evmScriptCallData
    ) internal pure returns (bytes memory _evmScript) {
        require(_methodIds.length == _evmScriptCallData.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < _methodIds.length; ++i) {
            _evmScript = bytes.concat(
                _evmScript,
                abi.encodePacked(
                    _to,
                    uint32(_evmScriptCallData[i].length) + 4,
                    _methodIds[i],
                    _evmScriptCallData[i]
                )
            );
        }
        _evmScript = bytes.concat(SPEC_ID, _evmScript);
    }

    /// @notice Encodes multiple calls to different contracts as EVMScript
    function createEVMScript(
        address[] memory _to,
        bytes4[] memory _methodIds,
        bytes[] memory _evmScriptCallData
    ) internal pure returns (bytes memory _evmScript) {
        require(_to.length == _methodIds.length, "LENGTH_MISMATCH");
        require(_to.length == _evmScriptCallData.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < _to.length; ++i) {
            _evmScript = bytes.concat(
                _evmScript,
                abi.encodePacked(
                    _to[i],
                    uint32(_evmScriptCallData[i].length) + 4,
                    _methodIds[i],
                    _evmScriptCallData[i]
                )
            );
        }
        _evmScript = bytes.concat(SPEC_ID, _evmScript);
    }
}
