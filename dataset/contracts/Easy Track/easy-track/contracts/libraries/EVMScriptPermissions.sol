// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "./BytesUtils.sol";

/// @author psirex
/// @notice Provides methods to convinient work with permissions bytes
/// @dev Permissions - is a list of tuples (address, bytes4) encoded into a bytes representation.
/// Each tuple (address, bytes4) describes a method allowed to be called by EVMScript
library EVMScriptPermissions {
    using BytesUtils for bytes;

    /// Stores length of one item in permissions.
    uint256 private constant PERMISSION_LENGTH = 24;

    /// @notice Validates that passed EVMScript calls only methods allowed in permissions.
    /// @dev Returns false if provided permissions are invalid (has a wrong length or empty)
    function canExecuteEVMScript(bytes memory _permissions, bytes memory _evmScript)
        internal
        pure
        returns (bool)
    {
        uint256 location = 4; // first 4 bytes reserved for SPEC_ID
        if (!isValidPermissions(_permissions) || _evmScript.length <= location) {
            return false;
        }

        while (location < _evmScript.length) {
            (bytes24 methodToCall, uint32 callDataLength) = _getNextMethodId(_evmScript, location);
            if (!_hasPermission(_permissions, methodToCall)) {
                return false;
            }
            location += PERMISSION_LENGTH + callDataLength;
        }
        return true;
    }

    /// @notice Validates that bytes with permissions not empty and has correct length
    function isValidPermissions(bytes memory _permissions) internal pure returns (bool) {
        return _permissions.length > 0 && _permissions.length % PERMISSION_LENGTH == 0;
    }

    // Retrieves bytes24 which describes tuple (address, bytes4)
    // from EVMScript starting from _location position
    function _getNextMethodId(bytes memory _evmScript, uint256 _location)
        private
        pure
        returns (bytes24, uint32)
    {
        address recipient = _evmScript.addressAt(_location);
        uint32 methodId = _evmScript.uint32At(_location + 24);
        uint32 callDataLength = _evmScript.uint32At(_location + 20);
        return (bytes24(uint192(methodId)) | bytes20(recipient), callDataLength);
    }

    // Validates that passed _methodToCall contained in permissions
    function _hasPermission(bytes memory _permissions, bytes24 _methodToCall)
        private
        pure
        returns (bool)
    {
        uint256 location = 0;
        while (location < _permissions.length) {
            bytes24 permission = _permissions.bytes24At(location);
            if (permission == _methodToCall) {
                return true;
            }
            location += PERMISSION_LENGTH;
        }
        return false;
    }
}
