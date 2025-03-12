// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StableCompToken is ERC20 {
    constructor() ERC20("StableCompToken", "SComp") {
        _mint(msg.sender, 3000000 * 10 ** decimals()); // todo supply
    }
}
