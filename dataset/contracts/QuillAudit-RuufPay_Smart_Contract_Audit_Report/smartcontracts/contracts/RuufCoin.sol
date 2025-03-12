// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract RuufCoin is ERC20 {

    constructor() ERC20("RuufCoin", "RUUF") {
        // Fix supply: 1.000.000.000 tokens
        _mint(msg.sender, 1000000000 * 10 ** 18);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
