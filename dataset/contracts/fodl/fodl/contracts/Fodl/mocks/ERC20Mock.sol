// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';

contract ERC20Mock is ERC20Burnable {
    constructor() public ERC20('MOCK', 'MOCK') {}

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }

    function multiMint(uint256 amount, address[] calldata targets) external {
        for (uint256 i = 0; i < targets.length; i++) {
            _mint(targets[i], amount);
        }
    }
}
