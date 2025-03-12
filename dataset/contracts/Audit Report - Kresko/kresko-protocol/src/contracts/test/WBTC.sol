// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import {WETH9} from "../vendor/WETH9.sol";

contract WBTC is WETH9 {
    mapping(address => bool) public minters;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        minters[msg.sender] = true;
        symbol = _symbol;
        name = _name;
        decimals = _decimals;
    }

    function toggleMinter(address minter) public {
        require(minters[msg.sender], "Not a minter");
        minters[minter] = !minters[minter];
    }

    function deposit() public payable override {
        revert("Use deposit(uint256 amount) instead");
    }

    function deposit(uint256 amount) public {
        require(minters[msg.sender], "Not a minter");
        balanceOf[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }
}
