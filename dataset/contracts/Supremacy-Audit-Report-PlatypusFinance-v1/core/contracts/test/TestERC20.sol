// DO NOT DEPLOY TO MAINNET
// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract TestERC20 is ERC20 {
    uint8 public d;

    constructor(
        string memory name,
        string memory symbol,
        uint8 _decimals,
        uint256 supply
    ) ERC20(name, symbol) {
        d = _decimals;
        _mint(msg.sender, supply);
    }

    function decimals() public view override returns (uint8) {
        return d;
    }

    function faucet(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}
