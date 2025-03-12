pragma solidity 0.6.12;

import "./TokenSoftToken.sol";
import "./capabilities/Blacklistable.sol";
import "./capabilities/RevocableToAddress.sol";

/**
 @title Tokensoft Token V2
 @notice This contract implements the ERC1404 Interface to add transfer restrictions to a standard ER20 token.
 The role based access controls allow the Owner accounts to determine which permissions are granted to admin accounts.
 Admin accounts can enable, disable, and configure the token restrictions built into the contract.
 */
contract TokenSoftTokenV2 is TokenSoftToken, Blacklistable, RevocableToAddress {

  /// @notice The from/to account has been explicitly denied the ability to send/receive
  uint8 public constant FAILURE_BLACKLIST = 3;
  string public constant FAILURE_BLACKLIST_MESSAGE = "Restricted due to blacklist";

   /**
   @notice Used to detect if a proposed transfer will be allowed
   @dev A 0 return value is success - all other codes should be displayed to user via messageForTransferRestriction
    */
  function detectTransferRestriction (address from, address to, uint256 amt)
        public
        override
        view
        returns (uint8)
    {
        // Restrictions are enabled, so verify the whitelist config allows the transfer.
        // Logic defined in Blacklistable parent class
        if(!checkBlacklistAllowed(from, to)) {
            return FAILURE_BLACKLIST;
        }

        return TokenSoftToken.detectTransferRestriction(from, to, amt);
    }

  /**
  @notice Returns a human readable string for the error returned via detectTransferRestriction
  */ 
  function messageForTransferRestriction (uint8 restrictionCode)
        public
        override
        view
        returns (string memory)
    {
        if (restrictionCode == FAILURE_BLACKLIST) {
            return FAILURE_BLACKLIST_MESSAGE;
        }
        
        return TokenSoftToken.messageForTransferRestriction(restrictionCode);
    }

    /**
     @notice Transfers tokens if they are not restricted
     @dev Overrides the parent class token transfer function to enforce restrictions.
     */
    function transfer (address to, uint256 value)
        public
        override(TokenSoftToken, ERC20)
        notRestricted(msg.sender, to, value)
        returns (bool success)
    {
        return TokenSoftToken.transfer(to, value);
    }

    /**
    @notice Transfers from a specified address if they are not restricted
    @dev Overrides the parent class token transferFrom function to enforce restrictions.
     */
    function transferFrom (address from, address to, uint256 value)
        public
        override(TokenSoftToken, ERC20)
        notRestricted(from, to, value)
        returns (bool success)
    {
        return TokenSoftToken.transferFrom(from, to, value);
    }
}