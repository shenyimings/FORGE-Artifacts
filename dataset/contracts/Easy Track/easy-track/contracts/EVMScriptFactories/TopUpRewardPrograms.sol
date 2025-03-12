// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "../TrustedCaller.sol";
import "../RewardProgramsRegistry.sol";
import "../interfaces/IFinance.sol";
import "../libraries/EVMScriptCreator.sol";
import "../interfaces/IEVMScriptFactory.sol";

/// @author psirex
/// @notice Creates EVMScript to top up balances of reward programs
contract TopUpRewardPrograms is TrustedCaller, IEVMScriptFactory {
    // -------------
    // ERRORS
    // -------------
    string private constant ERROR_LENGTH_MISMATCH = "LENGTH_MISMATCH";
    string private constant ERROR_EMPTY_DATA = "EMPTY_DATA";
    string private constant ERROR_ZERO_AMOUNT = "ZERO_AMOUNT";
    string private constant ERROR_REWARD_PROGRAM_NOT_ALLOWED = "REWARD_PROGRAM_NOT_ALLOWED";

    // -------------
    // VARIABLES
    // -------------

    /// @notice Address of Aragon's Finance contract
    IFinance public immutable finance;

    /// @notice Address of reward token
    address public immutable rewardToken;

    /// @notice Address of RewardProgramsRegistry
    RewardProgramsRegistry public immutable rewardProgramsRegistry;

    // -------------
    // CONSTRUCTOR
    // -------------

    constructor(
        address _trustedCaller,
        address _rewardProgramsRegistry,
        address _finance,
        address _rewardToken
    ) TrustedCaller(_trustedCaller) {
        finance = IFinance(_finance);
        rewardToken = _rewardToken;
        rewardProgramsRegistry = RewardProgramsRegistry(_rewardProgramsRegistry);
    }

    // -------------
    // EXTERNAL METHODS
    // -------------

    /// @notice Creates EVMScript to top up balances of reward programs
    /// @param _creator Address who creates EVMScript
    /// @param _evmScriptCallData Encoded tuple: (address[] _rewardPrograms, uint256[] _amounts) where
    /// _rewardPrograms - addresses of reward programs to top up
    /// _amounts - corresponding amount of tokens to transfer
    function createEVMScript(address _creator, bytes memory _evmScriptCallData)
        external
        view
        override
        onlyTrustedCaller(_creator)
        returns (bytes memory)
    {
        (address[] memory rewardPrograms, uint256[] memory amounts) =
            _decodeEVMScriptCallData(_evmScriptCallData);

        _validateEVMScriptCallData(rewardPrograms, amounts);

        bytes[] memory evmScriptsCalldata = new bytes[](rewardPrograms.length);
        for (uint256 i = 0; i < rewardPrograms.length; ++i) {
            evmScriptsCalldata[i] = abi.encode(
                rewardToken,
                rewardPrograms[i],
                amounts[i],
                "Reward program top up"
            );
        }
        return
            EVMScriptCreator.createEVMScript(
                address(finance),
                finance.newImmediatePayment.selector,
                evmScriptsCalldata
            );
    }

    /// @notice Decodes call data used by createEVMScript method
    /// @param _evmScriptCallData Encoded tuple: (address[] _rewardPrograms, uint256[] _amounts) where
    /// _rewardPrograms - addresses of reward programs to top up
    /// _amounts - corresponding amount of tokens to transfer
    /// @return _rewardPrograms Addresses of reward programs to top up
    /// @return _amounts Amounts of tokens to transfer
    function decodeEVMScriptCallData(bytes memory _evmScriptCallData)
        external
        pure
        returns (address[] memory _rewardPrograms, uint256[] memory _amounts)
    {
        return _decodeEVMScriptCallData(_evmScriptCallData);
    }

    // ------------------
    // PRIVATE METHODS
    // ------------------

    function _validateEVMScriptCallData(address[] memory _rewardPrograms, uint256[] memory _amounts)
        private
        view
    {
        require(_rewardPrograms.length == _amounts.length, ERROR_LENGTH_MISMATCH);
        require(_rewardPrograms.length > 0, ERROR_EMPTY_DATA);
        for (uint256 i = 0; i < _rewardPrograms.length; ++i) {
            require(_amounts[i] > 0, ERROR_ZERO_AMOUNT);
            require(
                rewardProgramsRegistry.isRewardProgram(_rewardPrograms[i]),
                ERROR_REWARD_PROGRAM_NOT_ALLOWED
            );
        }
    }

    function _decodeEVMScriptCallData(bytes memory _evmScriptCallData)
        private
        pure
        returns (address[] memory _rewardPrograms, uint256[] memory _amounts)
    {
        return abi.decode(_evmScriptCallData, (address[], uint256[]));
    }
}
