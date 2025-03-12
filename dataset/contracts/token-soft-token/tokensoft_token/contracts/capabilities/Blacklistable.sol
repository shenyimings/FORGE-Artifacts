pragma solidity 0.6.12;

import "../roles/BlacklisterRole.sol";

/**
Keeps track of Blacklists and can check if sender and reciever are configured to allow a transfer.
Only administrators can update the Blacklists.
 */
contract Blacklistable is BlacklisterRole {
    // Track whether Blacklisting is enabled
    bool public isBlacklistEnabled;

    // The mapping to keep track if an address is blacklisted
    mapping (address => bool) public addressBlacklists;

    // Events to allow tracking add/remove.
    event AddressAddedToBlacklist(address indexed addedAddress, address indexed addedBy);
    event AddressRemovedFromBlacklist(address indexed removedAddress, address indexed removedBy);    
    event BlacklistEnabledUpdated(address indexed updatedBy, bool indexed enabled);

    function _setBlacklistEnabled(bool enabled) internal {
        isBlacklistEnabled = enabled;
        emit BlacklistEnabledUpdated(msg.sender, enabled);
    }

    /**
    Sets an address's blacklisting status.  Only administrators should be allowed to update this.
     */
    function _addToBlacklist(address addressToAdd) internal {
        // Verify a valid address was passed in
        require(addressToAdd != address(0), "Cannot add 0x0");

        // Verify the address is on the blacklist before it can be removed
        require(!addressBlacklists[addressToAdd], "Already on list");

        // Set the address's white list ID
        addressBlacklists[addressToAdd] = true;

        // Emit the event for new Blacklist
        emit AddressAddedToBlacklist(addressToAdd, msg.sender);
    }

    /**
    Clears out an address from the blacklist.  Only administrators should be allowed to update this.
     */
    function _removeFromBlacklist(address addressToRemove) internal {
        // Verify a valid address was passed in
        require(addressToRemove != address(0), "Cannot remove 0x0");

        // Verify the address is on the blacklist before it can be removed
        require(addressBlacklists[addressToRemove], "Not on list");
        
        // Zero out the previous white list
        addressBlacklists[addressToRemove] = false;

        // Emit the event for tracking
        emit AddressRemovedFromBlacklist(addressToRemove, msg.sender);
    }


    /**
    Determine if the a sender is allowed to send to the receiver.
    If either the sender or receiver is blacklisted, then the transfer should be denied
     */
    function checkBlacklistAllowed(address sender, address receiver) public view returns (bool) {
        // If Blacklist enforcement is not enabled, then allow all
        if(!isBlacklistEnabled){
            return true;
        }

        // If either address is on the blacklist then fail
        return !addressBlacklists[sender] && !addressBlacklists[receiver];
    }

    /**
     * Enable or disable the Blacklist enforcement
     */
    function setBlacklistEnabled(bool enabled) public onlyOwner {
        _setBlacklistEnabled(enabled);
    }

    /**
    Public function that allows admins to remove an address from a Blacklist
     */
    function addToBlacklist(address addressToAdd) public onlyBlacklister {
        _addToBlacklist(addressToAdd);
    }

    /**
    Public function that allows admins to remove an address from a Blacklist
     */
    function removeFromBlacklist(address addressToRemove) public onlyBlacklister {
        _removeFromBlacklist(addressToRemove);
    }
}