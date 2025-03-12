// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./ERC20.sol";

contract MLand is ERC20Detailed, ERC20 {
    constructor() ERC20Detailed("Mland Token", "MLAND", 18) {
        uint256 totalTokens = 100000000 * 10**uint256(decimals());
        _mint(msg.sender, totalTokens);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
