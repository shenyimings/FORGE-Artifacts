// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "../libraries/EVMScriptPermissions.sol";

/// @author psirex
/// @notice Helper contract to test internal methods of EVMScriptPermissions library
contract EVMScriptPermissionsWrapper {
    function canExecuteEVMScript(bytes memory _permissions, bytes memory _evmScript)
        external
        pure
        returns (bool)
    {
        return EVMScriptPermissions.canExecuteEVMScript(_permissions, _evmScript);
    }

    function isValidPermissions(bytes memory _permissions) external pure returns (bool) {
        return EVMScriptPermissions.isValidPermissions(_permissions);
    }
}
