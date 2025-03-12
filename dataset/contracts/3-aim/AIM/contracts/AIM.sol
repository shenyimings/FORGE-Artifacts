// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AIM is ERC20, Ownable{

    constructor() ERC20("AI Meme Assistant", "AIM ") {	
        _mint(address(msg.sender), 500_000_000 * 10**18);
    }
}