// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Radikal Riders Token
/// @author Radikal Riders
/// @notice This is the utility ERC20 token of Radikal Riders
/// @dev Follows ERC20 standard with specific modifications 
contract ERC20RDK is ERC20, Ownable  {
    address[] radikalContracts;
    mapping(address=>uint) private _balancesTransferable;    
    
    constructor(
        address payable _tokenDistributorAddress
    ) 
        ERC20("Radikal Riders", "RDK") {
        address[] memory distributor = new address[](1);
        distributor[0] = _tokenDistributorAddress;
        addContracts(distributor);
        _mint(_tokenDistributorAddress, 5000000 * (10 ** 18));
    }

    // /********************************************************
    //  *                                                      *
    //  *                    MAIN FUNCTIONS                    *
    //  *                                                      *
    //  ********************************************************/
    
    /// @notice Tokens can only be transferred if they were utilized first
    /// @dev This function is executed before every token transfer
    /// @param from address from who the token is intended to be transferred
	/// @param to address to who the token is intended to be transferred
    /// @param amount amount of Tokens to be transferred
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        address[] memory _radikalContracts = radikalContracts;
        bool userToUser = true;
        for(uint i = 0; i < _radikalContracts.length; i++) {
           if(from == _radikalContracts[i] || to == _radikalContracts[i]) {
               userToUser = false;
               break;
           }
        }
        if(userToUser == true) {
            require(_balancesTransferable[from] >= amount, "ERC20: transfer amount exceeds transferable balance");
        }
    }

    /// @notice Update token transferable balances once tokens are transferred
    /// @dev This function is executed after every token transfer
    /// @param from address from who the token was transferred
	/// @param to address to who the token was transferred
    /// @param amount amount of Tokens transferred
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        address[] memory _radikalContracts = radikalContracts;
        bool fromContract = false;
        bool toContract = false;
        for(uint i = 0; i < _radikalContracts.length; i++) {
           if(from == _radikalContracts[i]) {
               fromContract = true;
               break;
           } else if(to == _radikalContracts[i]) {
               toContract = true;
               break;
           }
        }
        if(fromContract == false && toContract == false) {
            _balancesTransferable[from] -= amount;
        } else if(fromContract == true && toContract == false) {
            _balancesTransferable[to] += amount;
        } else if(fromContract == false && toContract == true) {
            uint balance = balanceOf(from);
            if(balance < _balancesTransferable[from]) {
                _balancesTransferable[from] = balance;
            }
        }
    }

    /********************************************************
     *                                                      *
     *                    ADMIN FUNCTIONS                   *
     *                                                      *
     ********************************************************/
    
    // Admin can add contracts to the list of Radikal contracts
    /// @notice Tokens sent to the listed contracts will be considered transferrable
    /// @dev Admin can add contracts to the list of Radikal contracts
    /// @param newContracts Address of the contract added to the whitelist
    function addContracts(address[] memory newContracts) public onlyOwner {
        for(uint i = 0; i < newContracts.length; i++) {
            radikalContracts.push(newContracts[i]);
        }
        
    }

    // Admin can add contracts to the list of Radikal contracts
    /// @notice Tokens sent to the listed contracts will be considered transferrable
    /// @dev Admin can add contracts to the list of Radikal contracts
    /// @param pairAddress Address of the contract added to the whitelist
    function addPair(address pairAddress) public onlyOwner {
        _balancesTransferable[pairAddress] = 50000000 * (10 ** 18);
    }

    /********************************************************
     *                                                      *
     *                    VIEW FUNCTIONS                    *
     *                                                      *
     ********************************************************/

    /// @notice Check balance of transferrable tokens (utilized first through one of the whitelisted contracts)
    /// @param account Address of the account to be evaluated
     function balanceTransferableOf(address account) public view returns (uint256) {
        return _balancesTransferable[account];
    }
}