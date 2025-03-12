// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "../TrustedCaller.sol";
import "../interfaces/IFinance.sol";
import "../libraries/EVMScriptCreator.sol";
import "../interfaces/IEVMScriptFactory.sol";

/// @author psirex
/// @notice Creates EVMScript to top up the address of the LEGO program
contract TopUpLegoProgram is TrustedCaller, IEVMScriptFactory {
    // -------------
    // ERRORS
    // -------------
    string private constant ERROR_LENGTH_MISMATCH = "LENGTH_MISMATCH";
    string private constant ERROR_EMPTY_DATA = "EMPTY_DATA";
    string private constant ERROR_ZERO_AMOUNT = "ZERO_AMOUNT";

    // -------------
    // VARIABLES
    // -------------

    /// @notice Address of Aragon's Finance contract
    IFinance public immutable finance;

    /// @notice Address of LEGO program
    address public immutable legoProgram;

    // -------------
    // CONSTRUCTOR
    // -------------

    constructor(
        address _trustedCaller,
        IFinance _finance,
        address _legoProgram
    ) TrustedCaller(_trustedCaller) {
        finance = _finance;
        legoProgram = _legoProgram;
    }

    // -------------
    // EXTERNAL METHODS
    // -------------

    /// @notice Creates EVMScript to top up the address of the LEGO program
    /// @param _creator Address who creates EVMScript
    /// @param _evmScriptCallData Encoded tuple: (address[] _rewardTokens, uint256[] _amounts) where
    /// _rewardTokens - addresses of ERC20 tokens (zero address for ETH) to transfer
    /// _amounts - corresponding amount of tokens to transfer
    function createEVMScript(address _creator, bytes memory _evmScriptCallData)
        external
        view
        override
        onlyTrustedCaller(_creator)
        returns (bytes memory)
    {
        (address[] memory rewardTokens, uint256[] memory amounts) =
            _decodeEVMScriptCallData(_evmScriptCallData);
        _validateEVMScriptCallData(rewardTokens, amounts);

        bytes[] memory paymentsCallData = new bytes[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            paymentsCallData[i] = abi.encode(
                rewardTokens[i],
                legoProgram,
                amounts[i],
                "Lego Program Transfer"
            );
        }

        return
            EVMScriptCreator.createEVMScript(
                address(finance),
                finance.newImmediatePayment.selector,
                paymentsCallData
            );
    }

    /// @notice Decodes call data used by createEVMScript method
    /// @param _evmScriptCallData Encoded tuple: (address[] _rewardTokens, uint256[] _amounts) where
    /// _rewardTokens - addresses of ERC20 tokens (zero address for ETH) to transfer
    /// _amounts - corresponding amount of tokens to transfer
    /// @return _rewardTokens Addresses of ERC20 tokens (zero address for ETH) to transfer
    /// @return _amounts Amounts of tokens to transfer
    function decodeEVMScriptCallData(bytes memory _evmScriptCallData)
        external
        pure
        returns (address[] memory _rewardTokens, uint256[] memory _amounts)
    {
        return _decodeEVMScriptCallData(_evmScriptCallData);
    }

    // ------------------
    // PRIVATE METHODS
    // ------------------

    function _validateEVMScriptCallData(address[] memory _rewardTokens, uint256[] memory _amounts)
        private
        pure
    {
        require(_rewardTokens.length == _amounts.length, ERROR_LENGTH_MISMATCH);
        require(_rewardTokens.length > 0, ERROR_EMPTY_DATA);
        for (uint256 i = 0; i < _rewardTokens.length; ++i) {
            require(_amounts[i] > 0, ERROR_ZERO_AMOUNT);
        }
    }

    function _decodeEVMScriptCallData(bytes memory _evmScriptCallData)
        private
        pure
        returns (address[] memory _rewardTokens, uint256[] memory _amounts)
    {
        return abi.decode(_evmScriptCallData, (address[], uint256[]));
    }
}
