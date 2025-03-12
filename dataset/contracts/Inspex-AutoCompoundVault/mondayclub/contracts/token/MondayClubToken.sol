// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MondayClubToken is ERC20("MondayClub TOKEN", "MONDAY") {
    constructor() {
        _mint(msg.sender, 1_000_000_000 ether);
    }  
}