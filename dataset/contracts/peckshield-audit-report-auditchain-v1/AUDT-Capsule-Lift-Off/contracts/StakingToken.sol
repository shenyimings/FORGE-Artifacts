// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Token to provide receipt for staked AUDT tokens.
 * @dev Burnable, Mintable, Ownable.
 */
contract StakingToken is
   
    ERC20,
    Ownable,
    AccessControl{
   
    // Create a new role identifier for the minter role
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");


    /**
     * @dev Sets the minter which is the Staking contract. 
     * @param minter - address of the minter 
     */
    constructor(address minter, string memory tokenSymbol, string memory tokenName) public ERC20(tokenName, tokenSymbol) {     
        _setupRole(MINTER_ROLE, minter);
    }

    /**
     * @dev Function to mint staking tokens for the user
     * @param user - address of the user receiving token
     * @param amount - amount of tokens to mint
     * @return boolean value true if action was successful 
     */
    function mint(address user, uint amount) public returns (bool) {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        require(user != address(0), "Recipient address can't be 0");       

        _mint(user, amount);        
        return true;
    }

     /**
     * @dev Function to burn staking tokens after user has redeemed their contribution
     * @param user - address of the user burning token
     * @param amount - amount of tokens to burn
     * @return boolean value true if action was successful 
     */
    function burn(address user, uint amount) public returns (bool) {
        require(hasRole(MINTER_ROLE, msg.sender), "StakingToken:burn - Caller is not a minter");
        require(user != address(0), "StakingToken:burn - Recipient address can't be 0");       
        _burn(user, amount);        
        return true;
    }
}
