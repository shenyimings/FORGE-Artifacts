pragma solidity 0.6.12;

import "./capabilities/Proxiable.sol";
import "./@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "./ERC1404.sol";
import "./roles/OwnerRole.sol";
import "./capabilities/Whitelistable.sol";
import "./capabilities/Mintable.sol";
import "./capabilities/Burnable.sol";
import "./capabilities/Revocable.sol";
import "./capabilities/Pausable.sol";

contract TokenSoftToken is Proxiable, ERC20Detailed, ERC1404, OwnerRole, Whitelistable, Mintable, Burnable, Revocable, Pausable {

    // ERC1404 Error codes and messages
    uint8 public constant SUCCESS_CODE = 0;
    uint8 public constant FAILURE_NON_WHITELIST = 1;
    uint8 public constant FAILURE_PAUSED = 2;
    string public constant SUCCESS_MESSAGE = "SUCCESS";
    string public constant FAILURE_NON_WHITELIST_MESSAGE = "The transfer was restricted due to white list configuration.";
    string public constant FAILURE_PAUSED_MESSAGE = "The transfer was restricted due to the contract being paused.";
    string public constant UNKNOWN_ERROR = "Unknown Error Code";


    /**
    Constructor for the token to set readable details and mint all tokens
    to the specified owner.
     */
    function initialize (address owner, string memory name, string memory symbol, uint8 decimals, uint256 initialSupply, bool whitelistEnabled)
        public
        initializer
    {
        ERC20Detailed.initialize(name, symbol, decimals);
        Mintable._mint(msg.sender, owner, initialSupply);
        OwnerRole._addOwner(owner);
        Whitelistable._setWhitelistEnabled(whitelistEnabled);
    }

    /**
    Public function to update the address of the code contract, retricted to owner
     */
    function updateCodeAddress (address newAddress) public onlyOwner {
        Proxiable._updateCodeAddress(newAddress);
    }

    /**
    This function detects whether a transfer should be restricted and not allowed.
    If the function returns SUCCESS_CODE (0) then it should be allowed.
     */
    function detectTransferRestriction (address from, address to, uint256)
        public
        view
        virtual
        override
        returns (uint8)
    {
        // Check the paused status of the contract
        if (Pausable.paused()) {
            return FAILURE_PAUSED;
        }

        // If an owner transferring, then ignore whitelist restrictions
        if(OwnerRole.isOwner(from)) {
            return SUCCESS_CODE;
        }

        // Restrictions are enabled, so verify the whitelist config allows the transfer.
        // Logic defined in Whitelistable parent class
        if(!checkWhitelistAllowed(from, to)) {
            return FAILURE_NON_WHITELIST;
        }

        // If no restrictions were triggered return success
        return SUCCESS_CODE;
    }

    /**
    This function allows a wallet or other client to get a human readable string to show
    a user if a transfer was restricted.  It should return enough information for the user
    to know why it failed.
     */
    function messageForTransferRestriction (uint8 restrictionCode)
        public
        view
        virtual
        override
        returns (string memory)
    {
        if (restrictionCode == SUCCESS_CODE) {
            return SUCCESS_MESSAGE;
        }

        if (restrictionCode == FAILURE_NON_WHITELIST) {
            return FAILURE_NON_WHITELIST_MESSAGE;
        }

        if (restrictionCode == FAILURE_PAUSED) {
            return FAILURE_PAUSED_MESSAGE;
        }

        // An unknown error code was passed in.
        return UNKNOWN_ERROR;
    }

    /**
    Evaluates whether a transfer should be allowed or not.
     */
    modifier notRestricted (address from, address to, uint256 value) {
        uint8 restrictionCode = detectTransferRestriction(from, to, value);
        require(restrictionCode == SUCCESS_CODE, messageForTransferRestriction(restrictionCode));
        _;
    }

    /**
    Overrides the parent class token transfer function to enforce restrictions.
     */
    function transfer (address to, uint256 value)
        public
        virtual
        override(ERC20, IERC20)
        notRestricted(msg.sender, to, value)
        returns (bool success)
    {
        success = ERC20.transfer(to, value);
    }

    /**
    Overrides the parent class token transferFrom function to enforce restrictions.
     */
    function transferFrom (address from, address to, uint256 value)
        public
        virtual
        override(ERC20, IERC20)
        notRestricted(from, to, value)
        returns (bool success)
    {
        success = ERC20.transferFrom(from, to, value);
    }
}
