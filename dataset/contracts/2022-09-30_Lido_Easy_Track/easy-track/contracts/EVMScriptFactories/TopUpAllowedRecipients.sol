// SPDX-FileCopyrightText: 2022 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "../TrustedCaller.sol";
import "../AllowedRecipientsRegistry.sol";
import "../interfaces/IFinance.sol";
import "../libraries/EVMScriptCreator.sol";
import "../interfaces/IEVMScriptFactory.sol";
import "../EasyTrack.sol";

/// @notice Creates EVMScript to top up allowed recipients addresses within the current spendable balance
contract TopUpAllowedRecipients is TrustedCaller, IEVMScriptFactory {
    // -------------
    // ERRORS
    // -------------
    string private constant ERROR_LENGTH_MISMATCH = "LENGTH_MISMATCH";
    string private constant ERROR_EMPTY_DATA = "EMPTY_DATA";
    string private constant ERROR_ZERO_AMOUNT = "ZERO_AMOUNT";
    string private constant ERROR_RECIPIENT_NOT_ALLOWED = "RECIPIENT_NOT_ALLOWED";
    string private constant ERROR_SUM_EXCEEDS_SPENDABLE_BALANCE = "SUM_EXCEEDS_SPENDABLE_BALANCE";

    // -------------
    // VARIABLES
    // -------------

    /// @notice Address of EasyTrack contract
    EasyTrack public immutable easyTrack;

    /// @notice Address of Aragon's Finance contract
    IFinance public immutable finance;

    /// @notice Address of payout token
    address public token;

    /// @notice Address of AllowedRecipientsRegistry contract
    AllowedRecipientsRegistry public allowedRecipientsRegistry;

    // -------------
    // CONSTRUCTOR
    // -------------

    /// @param _trustedCaller Address that has access to certain methods.
    ///     Set once on deployment and can't be changed.
    /// @param _allowedRecipientsRegistry Address of AllowedRecipientsRegistry contract
    /// @param _finance Address of Aragon's Finance contract
    /// @param _token Address of payout token
    /// @param _easyTrack Address of EasyTrack contract
    constructor(
        address _trustedCaller,
        address _allowedRecipientsRegistry,
        address _finance,
        address _token,
        address _easyTrack
    ) TrustedCaller(_trustedCaller) {
        finance = IFinance(_finance);
        token = _token;
        allowedRecipientsRegistry = AllowedRecipientsRegistry(_allowedRecipientsRegistry);
        easyTrack = EasyTrack(_easyTrack);
    }

    // -------------
    // EXTERNAL METHODS
    // -------------

    /// @notice Creates EVMScript to top up allowed recipients addresses
    /// @param _creator Address who creates EVMScript
    /// @param _evmScriptCallData Encoded tuple: (address[] recipients, uint256[] amounts) where
    /// recipients - addresses of recipients to top up
    /// amounts - corresponding amounts of token to transfer
    /// @dev note that the arrays below has one extra element to store limit enforcement calls
    function createEVMScript(address _creator, bytes memory _evmScriptCallData)
        external
        view
        override
        onlyTrustedCaller(_creator)
        returns (bytes memory)
    {
        (address[] memory recipients, uint256[] memory amounts) = _decodeEVMScriptCallData(
            _evmScriptCallData
        );
        uint256 totalAmount = _validateEVMScriptCallData(recipients, amounts);

        address[] memory to = new address[](recipients.length + 1);
        bytes4[] memory methodIds = new bytes4[](recipients.length + 1);
        bytes[] memory evmScriptsCalldata = new bytes[](recipients.length + 1);

        to[0] = address(allowedRecipientsRegistry);
        methodIds[0] = allowedRecipientsRegistry.updateSpentAmount.selector;
        evmScriptsCalldata[0] = abi.encode(totalAmount);

        for (uint256 i = 0; i < recipients.length; ++i) {
            to[i + 1] = address(finance);
            methodIds[i + 1] = finance.newImmediatePayment.selector;
            evmScriptsCalldata[i + 1] = abi.encode(
                token,
                recipients[i],
                amounts[i],
                "Top up allowed recipients"
            );
        }

        return EVMScriptCreator.createEVMScript(to, methodIds, evmScriptsCalldata);
    }

    /// @notice Decodes call data used by createEVMScript method
    /// @param _evmScriptCallData Encoded tuple: (address[] recipients, uint256[] amounts) where
    /// recipients - addresses of recipients to top up
    /// amounts - corresponding amounts of token to transfer
    /// @return recipients Addresses of recipients to top up
    /// @return amounts Amounts of token to transfer
    function decodeEVMScriptCallData(bytes memory _evmScriptCallData)
        external
        pure
        returns (address[] memory recipients, uint256[] memory amounts)
    {
        return _decodeEVMScriptCallData(_evmScriptCallData);
    }

    // ------------------
    // PRIVATE METHODS
    // ------------------

    function _validateEVMScriptCallData(address[] memory _recipients, uint256[] memory _amounts)
        private
        view
        returns (uint256 totalAmount)
    {
        require(_amounts.length == _recipients.length, ERROR_LENGTH_MISMATCH);
        require(_recipients.length > 0, ERROR_EMPTY_DATA);

        for (uint256 i = 0; i < _recipients.length; ++i) {
            require(_amounts[i] > 0, ERROR_ZERO_AMOUNT);
            require(
                allowedRecipientsRegistry.isRecipientAllowed(_recipients[i]),
                ERROR_RECIPIENT_NOT_ALLOWED
            );
            totalAmount += _amounts[i];
        }

        _validateSpendableBalance(totalAmount);
    }

    function _decodeEVMScriptCallData(bytes memory _evmScriptCallData)
        private
        pure
        returns (address[] memory recipients, uint256[] memory amounts)
    {
        return abi.decode(_evmScriptCallData, (address[], uint256[]));
    }

    function _validateSpendableBalance(uint256 _amount) private view {
        require(
            allowedRecipientsRegistry.isUnderSpendableBalance(_amount, easyTrack.motionDuration()),
            ERROR_SUM_EXCEEDS_SPENDABLE_BALANCE
        );
    }
}
