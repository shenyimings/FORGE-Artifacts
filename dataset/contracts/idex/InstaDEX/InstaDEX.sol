// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

///	@title	InstaDEX token contract
contract InstaDEX is ERC20Permit {

    constructor() ERC20("InstaDEX", "IDEX") ERC20Permit("InstaDEX") {
        _mint(msg.sender, 100_000_000e18);
    }
}