// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FocialNetwork is ERC20 {
    constructor() ERC20("Focial Network", "FOCIAL") {
        _mint(msg.sender, 500000000 * 10 ** decimals());
    }
}