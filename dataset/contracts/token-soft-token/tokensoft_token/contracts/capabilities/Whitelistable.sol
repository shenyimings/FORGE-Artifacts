pragma solidity 0.6.12;

import "../roles/WhitelisterRole.sol";

/**
Keeps track of whitelists and can check if sender and reciever are configured to allow a transfer.
Only administrators can update the whitelists.
Any address can only be a member of one whitelist at a time.
 */
contract Whitelistable is WhitelisterRole {
    // Track whether whitelisting is enabled
    bool public isWhitelistEnabled;

    // Zero is reserved for indicating it is not on a whitelist
    uint8 constant NO_WHITELIST = 0;

    // The mapping to keep track of which whitelist any address belongs to.
    // 0 is reserved for no whitelist and is the default for all addresses.
    mapping (address => uint8) public addressWhitelists;

    // The mapping to keep track of each whitelist's outbound whitelist flags.
    // Boolean flag indicates whether outbound transfers are enabled.
    mapping(uint8 => mapping (uint8 => bool)) public outboundWhitelistsEnabled;

    // Events to allow tracking add/remove.
    event AddressAddedToWhitelist(address indexed addedAddress, uint8 indexed whitelist, address indexed addedBy);
    event AddressRemovedFromWhitelist(address indexed removedAddress, uint8 indexed whitelist, address indexed removedBy);
    event OutboundWhitelistUpdated(
        address indexed updatedBy, uint8 indexed sourceWhitelist, uint8 indexed destinationWhitelist, bool from, bool to);
    event WhitelistEnabledUpdated(address indexed updatedBy, bool indexed enabled);

    function _setWhitelistEnabled(bool enabled) internal {
        isWhitelistEnabled = enabled;
        emit WhitelistEnabledUpdated(msg.sender, enabled);
    }

    /**
    Sets an address's white list ID.  Only administrators should be allowed to update this.
    If an address is on an existing whitelist, it will just get updated to the new value (removed from previous).
     */
    function _addToWhitelist(address addressToAdd, uint8 whitelist) internal {
        // Verify a valid address was passed in
        require(addressToAdd != address(0), "Cannot add address 0x0 to a whitelist.");

        // Verify the whitelist is valid
        require(whitelist != NO_WHITELIST, "Invalid whitelist ID supplied");

        // Save off the previous white list
        uint8 previousWhitelist = addressWhitelists[addressToAdd];

        // Set the address's white list ID
        addressWhitelists[addressToAdd] = whitelist;

        // If the previous whitelist existed then we want to indicate it has been removed
        if(previousWhitelist != NO_WHITELIST) {
            // Emit the event for tracking
            emit AddressRemovedFromWhitelist(addressToAdd, previousWhitelist, msg.sender);
        }

        // Emit the event for new whitelist
        emit AddressAddedToWhitelist(addressToAdd, whitelist, msg.sender);
    }

    /**
    Clears out an address's white list ID.  Only administrators should be allowed to update this.
     */
    function _removeFromWhitelist(address addressToRemove) internal {
        // Verify a valid address was passed in
        require(addressToRemove != address(0), "Cannot remove address 0x0 from a whitelist.");

        // Save off the previous white list
        uint8 previousWhitelist = addressWhitelists[addressToRemove];

        // Verify the address was actually on a whitelist
        require(previousWhitelist != NO_WHITELIST, "Address cannot be removed from invalid whitelist.");

        // Zero out the previous white list
        addressWhitelists[addressToRemove] = NO_WHITELIST;

        // Emit the event for tracking
        emit AddressRemovedFromWhitelist(addressToRemove, previousWhitelist, msg.sender);
    }

    /**
    Sets the flag to indicate whether source whitelist is allowed to send to destination whitelist.
    Only administrators should be allowed to update this.
     */
    function _updateOutboundWhitelistEnabled(uint8 sourceWhitelist, uint8 destinationWhitelist, bool newEnabledValue) internal {
        // Get the old enabled flag
        bool oldEnabledValue = outboundWhitelistsEnabled[sourceWhitelist][destinationWhitelist];

        // Update to the new value
        outboundWhitelistsEnabled[sourceWhitelist][destinationWhitelist] = newEnabledValue;

        // Emit event for tracking
        emit OutboundWhitelistUpdated(msg.sender, sourceWhitelist, destinationWhitelist, oldEnabledValue, newEnabledValue);
    }

    /**
    Determine if the a sender is allowed to send to the receiver.
    The source whitelist must be enabled to send to the whitelist where the receive exists.
     */
    function checkWhitelistAllowed(address sender, address receiver) public view returns (bool) {
        // If whitelist enforcement is not enabled, then allow all
        if(!isWhitelistEnabled){
            return true;
        }

        // First get each address white list
        uint8 senderWhiteList = addressWhitelists[sender];
        uint8 receiverWhiteList = addressWhitelists[receiver];

        // If either address is not on a white list then the check should fail
        if(senderWhiteList == NO_WHITELIST || receiverWhiteList == NO_WHITELIST){
            return false;
        }

        // Determine if the sending whitelist is allowed to send to the destination whitelist
        return outboundWhitelistsEnabled[senderWhiteList][receiverWhiteList];
    }

    /**
     * Enable or disable the whitelist enforcement
     */
    function setWhitelistEnabled(bool enabled) public onlyOwner {
        _setWhitelistEnabled(enabled);
    }

    /**
    Public function that allows admins to remove an address from a whitelist
     */
    function addToWhitelist(address addressToAdd, uint8 whitelist) public onlyWhitelister {
        _addToWhitelist(addressToAdd, whitelist);
    }

    /**
    Public function that allows admins to remove an address from a whitelist
     */
    function removeFromWhitelist(address addressToRemove) public onlyWhitelister {
        _removeFromWhitelist(addressToRemove);
    }

    /**
    Public function that allows admins to update outbound whitelists
     */
    function updateOutboundWhitelistEnabled(uint8 sourceWhitelist, uint8 destinationWhitelist, bool newEnabledValue) public onlyWhitelister {
        _updateOutboundWhitelistEnabled(sourceWhitelist, destinationWhitelist, newEnabledValue);
    }
}