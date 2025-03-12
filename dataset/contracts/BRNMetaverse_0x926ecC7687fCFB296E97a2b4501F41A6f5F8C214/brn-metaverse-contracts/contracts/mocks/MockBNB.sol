// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockBNB is ERC20 {
    constructor() ERC20("Mock BNB", "BNB") {
        _mint(msg.sender, 1000000000000000000);
    }
}