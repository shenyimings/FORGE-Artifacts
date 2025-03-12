pragma solidity 0.6.12;

import "../capabilities/Proxiable.sol";
import "../@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "../roles/OwnerRole.sol";
import "../capabilities/Whitelistable.sol";
import "../capabilities/Mintable.sol";
import "../capabilities/Burnable.sol";
import "../capabilities/Revocable.sol";
import "../capabilities/Pausable.sol";
import "./Escrowable.sol";

contract TokenSoftTokenEscrow is Proxiable, ERC20Detailed, OwnerRole, Whitelistable, Mintable, Burnable, Revocable, Pausable, Escrowable {

    // ERC1404 Error codes and messages`
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
    Restrict rejectTransferProposals to admins only
     */
    function rejectTransferProposal(uint requestId) public onlyEscrower {
      Escrowable._rejectTransferProposal(requestId);
    }

    /**
    Restrict approveTransferProposals to admins only
     */
    function approveTransferProposal(uint requestId) public onlyEscrower {
      Escrowable._approveTransferProposal(requestId);
    }

    /**
    Overrides the parent class token transfer function to enforce restrictions.
     */
    function transfer (address to, uint256 value)
        public
        override(IERC20, ERC20)
        returns (bool success)
    {
        success = Escrowable._createTransferProposal(to, value);
    }

    /**
    Overrides the parent class token transferFrom function to enforce restrictions.
    Note that the approved amount of tokens the sender can transfer does not get reimbursed if the
    Transfer proposal is rejcted or canceled.
     */
    function transferFrom (address from, address to, uint256 value)
        public
        override(IERC20, ERC20)
        returns (bool success)
    {
        success = Escrowable._createTransferFromProposal(from, to, value);
    }
}
