// contracts/GLDToken.sol
// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ExecutorToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Exec", "EXE") {
        _mint(msg.sender, initialSupply);
    }
}
