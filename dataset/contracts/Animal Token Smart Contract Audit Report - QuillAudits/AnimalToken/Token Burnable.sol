// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

/**
 * @title TokenBEP20

 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract Token is ERC20, ERC20Burnable {
constructor() ERC20("Token", "Token") {
    
_mint(msg.sender, 100000000e18); //100,000,000 tokens totalsupply
}
}
