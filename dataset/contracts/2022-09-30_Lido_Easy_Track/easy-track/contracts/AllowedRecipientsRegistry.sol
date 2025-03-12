// SPDX-FileCopyrightText: 2022 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "./LimitsChecker.sol";

/// @author psirex, zuzueeka
/// @title Registry of allowed addresses for payouts
/// @notice Stores list of allowed addresses
contract AllowedRecipientsRegistry is LimitsChecker {
    // -------------
    // EVENTS
    // -------------
    event RecipientAdded(address indexed _recipient, string _title);
    event RecipientRemoved(address indexed _recipient);

    // -------------
    // ROLES
    // -------------
    bytes32 public constant ADD_RECIPIENT_TO_ALLOWED_LIST_ROLE =
        keccak256("ADD_RECIPIENT_TO_ALLOWED_LIST_ROLE");
    bytes32 public constant REMOVE_RECIPIENT_FROM_ALLOWED_LIST_ROLE =
        keccak256("REMOVE_RECIPIENT_FROM_ALLOWED_LIST_ROLE");

    // -------------
    // ERRORS
    // -------------
    string private constant ERROR_RECIPIENT_ALREADY_ADDED_TO_ALLOWED_LIST =
        "RECIPIENT_ALREADY_ADDED_TO_ALLOWED_LIST";
    string private constant ERROR_RECIPIENT_NOT_FOUND_IN_ALLOWED_LIST =
        "RECIPIENT_NOT_FOUND_IN_ALLOWED_LIST";

    // -------------
    // VARIABLES
    // -------------

    /// @dev List of allowed addresses for payouts
    address[] public allowedRecipients;

    // Position of the address in the `allowedRecipients` array,
    // plus 1 because index 0 means a value is not in the set.
    mapping(address => uint256) private allowedRecipientIndices;

    // -------------
    // CONSTRUCTOR
    // -------------

    /// @param _admin Address which will be granted with role DEFAULT_ADMIN_ROLE
    /// @param _addRecipientToAllowedListRoleHolders List of addresses which will be
    ///     granted with role ADD_RECIPIENT_TO_ALLOWED_LIST_ROLE
    /// @param _removeRecipientFromAllowedListRoleHolders List of addresses which will
    ///     be granted with role REMOVE_RECIPIENT_FROM_ALLOWED_LIST_ROLE
    /// @param _setLimitParametersRoleHolders List of addresses which will
    ///     be granted with role SET_LIMIT_PARAMETERS_ROLE
    /// @param _updateSpentAmountRoleHolders List of addresses which will
    ///     be granted with role UPDATE_SPENT_AMOUNT_ROLE
    /// @param _bokkyPooBahsDateTimeContract Address of bokkyPooBahs DateTime Contract
    constructor(
        address _admin,
        address[] memory _addRecipientToAllowedListRoleHolders,
        address[] memory _removeRecipientFromAllowedListRoleHolders,
        address[] memory _setLimitParametersRoleHolders,
        address[] memory _updateSpentAmountRoleHolders,
        IBokkyPooBahsDateTimeContract _bokkyPooBahsDateTimeContract
    )
        LimitsChecker(
            _setLimitParametersRoleHolders,
            _updateSpentAmountRoleHolders,
            _bokkyPooBahsDateTimeContract
        )
    {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        for (uint256 i = 0; i < _addRecipientToAllowedListRoleHolders.length; i++) {
            _setupRole(
                ADD_RECIPIENT_TO_ALLOWED_LIST_ROLE,
                _addRecipientToAllowedListRoleHolders[i]
            );
        }
        for (uint256 i = 0; i < _removeRecipientFromAllowedListRoleHolders.length; i++) {
            _setupRole(
                REMOVE_RECIPIENT_FROM_ALLOWED_LIST_ROLE,
                _removeRecipientFromAllowedListRoleHolders[i]
            );
        }
    }

    // -------------
    // EXTERNAL METHODS
    // -------------

    /// @notice Adds address to list of allowed addresses for payouts
    function addRecipient(address _recipient, string memory _title)
        external
        onlyRole(ADD_RECIPIENT_TO_ALLOWED_LIST_ROLE)
    {
        require(
            allowedRecipientIndices[_recipient] == 0,
            ERROR_RECIPIENT_ALREADY_ADDED_TO_ALLOWED_LIST
        );

        allowedRecipients.push(_recipient);
        allowedRecipientIndices[_recipient] = allowedRecipients.length;
        emit RecipientAdded(_recipient, _title);
    }

    /// @notice Removes address from list of allowed addresses for payouts
    /// @dev To delete an allowed address from the allowedRecipients array in O(1),
    /// we swap the element to delete with the last one in the array,
    /// and then remove the last element (sometimes called as 'swap and pop').
    function removeRecipient(address _recipient)
        external
        onlyRole(REMOVE_RECIPIENT_FROM_ALLOWED_LIST_ROLE)
    {
        uint256 index = _getAllowedRecipientIndex(_recipient);
        uint256 lastIndex = allowedRecipients.length - 1;

        if (index != lastIndex) {
            address lastAllowedRecipient = allowedRecipients[lastIndex];
            allowedRecipients[index] = lastAllowedRecipient;
            allowedRecipientIndices[lastAllowedRecipient] = index + 1;
        }

        allowedRecipients.pop();
        delete allowedRecipientIndices[_recipient];
        emit RecipientRemoved(_recipient);
    }

    /// @notice Returns if passed address is listed as allowed recipient in the registry
    function isRecipientAllowed(address _address) external view returns (bool) {
        return allowedRecipientIndices[_address] > 0;
    }

    /// @notice Returns current list of allowed recipients
    function getAllowedRecipients() external view returns (address[] memory) {
        return allowedRecipients;
    }

    // ------------------
    // PRIVATE METHODS
    // ------------------

    function _getAllowedRecipientIndex(address _evmScriptFactory)
        private
        view
        returns (uint256 _index)
    {
        _index = allowedRecipientIndices[_evmScriptFactory];
        require(_index > 0, ERROR_RECIPIENT_NOT_FOUND_IN_ALLOWED_LIST);
        _index -= 1;
    }
}
