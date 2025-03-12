// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Coin is ERC20("Crush Token", "CRUSH") {
    
    function mint(address _benefactor, uint256 amount) public{
        _mint(_benefactor, amount);
    }
}