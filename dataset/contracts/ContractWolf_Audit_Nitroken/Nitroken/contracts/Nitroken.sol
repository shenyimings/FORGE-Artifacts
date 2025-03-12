// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Nitroken is ERC20 {
    constructor() ERC20("Nitroken", "NITO") {
        _mint(msg.sender, 500000000 * 10 ** decimals());
    }
}