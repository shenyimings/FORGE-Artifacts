// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "./interfaces/IEVMScriptFactory.sol";
import "./libraries/EVMScriptPermissions.sol";
import "./EasyTrackStorage.sol";

/// @author psirex
/// @notice Provides methods to add/remove EVMScript factories
/// and contains an internal method for the convenient creation of EVMScripts
contract EVMScriptFactoriesRegistry is EasyTrackStorage {
    using EVMScriptPermissions for bytes;

    // -------------
    // EVENTS
    // -------------

    event EVMScriptFactoryAdded(address indexed _evmScriptFactory, bytes _permissions);
    event EVMScriptFactoryRemoved(address indexed _evmScriptFactory);

    // ------------------
    // EXTERNAL METHODS
    // ------------------

    /// @notice Adds new EVMScript Factory to the list of allowed EVMScript factories with given permissions
    function addEVMScriptFactory(address _evmScriptFactory, bytes memory _permissions)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_permissions.isValidPermissions(), "INVALID_PERMISSIONS");
        require(!_isEVMScriptFactory(_evmScriptFactory), "EVM_SCRIPT_FACTORY_ALREADY_ADDED");
        evmScriptFactories.push(_evmScriptFactory);
        evmScriptFactoryIndices[_evmScriptFactory] = evmScriptFactories.length;
        evmScriptFactoryPermissions[_evmScriptFactory] = _permissions;
        emit EVMScriptFactoryAdded(_evmScriptFactory, _permissions);
    }

    /// @notice Removes EVMScript factory from the list of allowed EVMScript factories
    /// @dev To delete a EVMScript factory from the rewardPrograms array in O(1),
    /// we swap the element to delete with the last one in the array, and then remove
    /// the last element (sometimes called as 'swap and pop').
    function removeEVMScriptFactory(address _evmScriptFactory)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        uint256 index = _getEVMScriptFactoryIndex(_evmScriptFactory);
        uint256 lastIndex = evmScriptFactories.length - 1;

        if (index != lastIndex) {
            address lastEVMScriptFactory = evmScriptFactories[lastIndex];
            evmScriptFactories[index] = lastEVMScriptFactory;
            evmScriptFactoryIndices[lastEVMScriptFactory] = index + 1;
        }

        evmScriptFactories.pop();
        delete evmScriptFactoryIndices[_evmScriptFactory];
        delete evmScriptFactoryPermissions[_evmScriptFactory];
        emit EVMScriptFactoryRemoved(_evmScriptFactory);
    }

    /// @notice Returns current list of EVMScript factories
    function getEVMScriptFactories() external view returns (address[] memory) {
        return evmScriptFactories;
    }

    /// @notice Returns if passed address are listed as EVMScript factory in the registry
    function isEVMScriptFactory(address _maybeEVMScriptFactory) external view returns (bool) {
        return _isEVMScriptFactory(_maybeEVMScriptFactory);
    }

    // ------------------
    // INTERNAL METHODS
    // ------------------

    /// @notice Creates EVMScript using given EVMScript factory
    /// @dev Checks permissions of resulting EVMScript and reverts with error
    /// if script tries to call methods not listed in permissions
    function _createEVMScript(
        address _evmScriptFactory,
        address _creator,
        bytes memory _evmScriptCallData
    ) internal returns (bytes memory _evmScript) {
        require(_isEVMScriptFactory(_evmScriptFactory), "EVM_SCRIPT_FACTORY_NOT_FOUND");
        _evmScript = IEVMScriptFactory(_evmScriptFactory).createEVMScript(
            _creator,
            _evmScriptCallData
        );
        bytes memory permissions = evmScriptFactoryPermissions[_evmScriptFactory];
        require(permissions.canExecuteEVMScript(_evmScript), "HAS_NO_PERMISSIONS");
    }

    // ------------------
    // PRIVATE METHODS
    // ------------------

    function _getEVMScriptFactoryIndex(address _evmScriptFactory)
        private
        view
        returns (uint256 _index)
    {
        _index = evmScriptFactoryIndices[_evmScriptFactory];
        require(_index > 0, "EVM_SCRIPT_FACTORY_NOT_FOUND");
        _index -= 1;
    }

    function _isEVMScriptFactory(address _maybeEVMScriptFactory) private view returns (bool) {
        return evmScriptFactoryIndices[_maybeEVMScriptFactory] > 0;
    }
}
