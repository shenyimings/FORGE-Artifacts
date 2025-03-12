// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC20} from "kresko-lib/token/ERC20.sol";

contract MockWBTC is ERC20("Wrapped BTC", "WBTC", 8) {
    event Deposit(address indexed dst, uint256 wad);

    mapping(address => bool) public minters;

    constructor() {
        minters[msg.sender] = true;
    }

    function toggleMinter(address minter) public {
        require(minters[msg.sender], "Not a minter");
        minters[minter] = !minters[minter];
    }

    function deposit() public payable {
        revert("WBTC: use deposit(uint256)");
    }

    function deposit(uint256 amount) public {
        require(minters[msg.sender], "Not a minter");
        _balances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }
}
