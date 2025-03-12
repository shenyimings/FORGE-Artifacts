// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FanadiseBEP20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address recipient
    ) ERC20(name, symbol) {
        _mint(recipient, initialSupply);
    }
}
