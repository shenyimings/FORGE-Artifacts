//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Roosty is ERC20{
    constructor () ERC20("Roosty Fi", "ROOSTY"){
         _mint(msg.sender, 1000000000 * (10 ** uint256(decimals())));
    }
}

