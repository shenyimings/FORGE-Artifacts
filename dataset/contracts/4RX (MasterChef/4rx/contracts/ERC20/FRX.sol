// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract FRX is ERC20 {
    constructor() public ERC20("FRX", "4RX") {
        _setupDecimals(8);
        _mint(msg.sender, 1000000000*(10**8)); // 1 Billion, 8 decimals
    }
}
