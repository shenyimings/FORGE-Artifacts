// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
// console.log("Unlock time is %o and block timestamp is %o", unlockTime, block.timestamp);

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Token is Ownable, ERC20{
    ///Test token dont deploy
    constructor(string memory name, string memory symbol) Ownable(msg.sender) ERC20(name,symbol){}
    function mint(address to, uint amount) public onlyOwner(){
        _mint(to, amount);
    } 
}
