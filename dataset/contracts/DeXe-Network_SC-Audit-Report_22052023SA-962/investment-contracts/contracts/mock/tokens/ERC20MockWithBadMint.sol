// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC20Mock.sol";

contract ERC20MockWithBadMint is ERC20Mock {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimalPlaces
    ) ERC20Mock(name, symbol, decimalPlaces) {}

    function mint(address to, uint256 _amount) external override {
        return;
    }
}
