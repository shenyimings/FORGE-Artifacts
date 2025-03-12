// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "../TrustedCaller.sol";
import "../RewardProgramsRegistry.sol";
import "../libraries/EVMScriptCreator.sol";
import "../interfaces/IEVMScriptFactory.sol";

/// @author psirex
/// @notice Creates EVMScript to add new reward program address to RewardProgramsRegistry
contract AddRewardProgram is TrustedCaller, IEVMScriptFactory {
    // -------------
    // ERRORS
    // -------------
    string private constant ERROR_REWARD_PROGRAM_ALREADY_ADDED = "REWARD_PROGRAM_ALREADY_ADDED";

    // -------------
    // VARIABLES
    // -------------

    /// @notice Address of RewardsProgramsRegistry
    RewardProgramsRegistry public immutable rewardProgramsRegistry;

    // -------------
    // CONSTRUCTOR
    // -------------

    constructor(address _trustedCaller, address _rewardProgramsRegistry)
        TrustedCaller(_trustedCaller)
    {
        rewardProgramsRegistry = RewardProgramsRegistry(_rewardProgramsRegistry);
    }

    // -------------
    // EXTERNAL METHODS
    // -------------

    /// @notice Creates EVMScript to add new reward program address to RewardProgramsRegistry
    /// @param _creator Address who creates EVMScript
    /// @param _evmScriptCallData Encoded tuple: (address _rewardProgram)
    function createEVMScript(address _creator, bytes memory _evmScriptCallData)
        external
        view
        override
        onlyTrustedCaller(_creator)
        returns (bytes memory)
    {
        require(
            !rewardProgramsRegistry.isRewardProgram(_decodeEVMScriptCallData(_evmScriptCallData)),
            ERROR_REWARD_PROGRAM_ALREADY_ADDED
        );

        return
            EVMScriptCreator.createEVMScript(
                address(rewardProgramsRegistry),
                rewardProgramsRegistry.addRewardProgram.selector,
                _evmScriptCallData
            );
    }

    /// @notice Decodes call data used by createEVMScript method
    /// @param _evmScriptCallData Encoded tuple: (address _rewardProgram)
    /// @return _rewardProgram Address of new reward program
    function decodeEVMScriptCallData(bytes memory _evmScriptCallData)
        external
        pure
        returns (address)
    {
        return _decodeEVMScriptCallData(_evmScriptCallData);
    }

    // ------------------
    // PRIVATE METHODS
    // ------------------

    function _decodeEVMScriptCallData(bytes memory _evmScriptCallData)
        private
        pure
        returns (address)
    {
        return abi.decode(_evmScriptCallData, (address));
    }
}
