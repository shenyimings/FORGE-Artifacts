// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CrafteoToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("CrafteoAI", "NFTC") {
        _mint(msg.sender, initialSupply);
    }
}