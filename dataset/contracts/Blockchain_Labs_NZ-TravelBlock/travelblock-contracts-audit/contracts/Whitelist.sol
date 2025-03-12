pragma solidity ^0.4.24;


import "./Admin.sol";


/// @title Whitelist configurations for the TRVL Token contract.
contract Whitelist is Admin {
    mapping(address => bool) public whitelist;

    event WhitelistAdded(address added);
    event WhitelistRemoved(address removed);

    /// @dev Verifies the user is whitelisted.
    modifier isWhitelisted(address _user) {
        require(whitelist[_user] != false, "User is not whitelisted!");
        _;
    }

    /// @notice Adds a list of addresses to the whitelist.
    /// @dev Requires that the msg.sender is the Admin. Emits an event on success.
    /// @param _users The list of addresses to add to the whitelist.
    function addAddressesToWhitelist(address[] _users) external onlyAdmin {
        require(_users.length > 0, "Cannot add an empty list to whitelist!");
        for (uint256 i = 0; i < _users.length; ++i) {
            address user = _users[i];
            require(user != address(0), "Cannot add the zero address to whitelist!");

            if (!whitelist[user]) {
                whitelist[user] = true;

                emit WhitelistAdded(user);
            }
        }
    }

    /// @notice Removes a list of addresses from the whitelist.
    /// @dev Requires that the msg.sender is an Admin. Emits an event on success.
    /// @param _users The list of addresses to remove from the whitelist.
    function removeAddressesFromWhitelist(address[] _users) external onlyAdmin {
        require(_users.length > 0, "Cannot remove an empty list to whitelist!");
        for (uint256 i = 0; i < _users.length; ++i) {
            address user = _users[i];

            if (whitelist[user]) {
                whitelist[user] = false;

                emit WhitelistRemoved(user);
            }
        }
    }
}
