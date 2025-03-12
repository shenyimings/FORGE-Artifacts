// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ASPOToken is ERC20 {
    constructor() ERC20("ASPOToken", "ASPO") {
        _mint(msg.sender, 500000000 * 10 ** decimals());
    }
}