//SPDX-License-Identifier: Unlicense
pragma solidity  ^0.8.0;

import "./LERC20.sol";

contract LERC20Mock is LERC20 {
    constructor (
        uint256 totalSupply,
        string memory name,
        string memory symbol,
        address initialAccount,
        uint256 initialBalance,
        address lssAddress,
        address admin,
        address adminBackup,
         uint256 _timelockPeriod
    ) payable LERC20(totalSupply, name, symbol, admin, adminBackup, _timelockPeriod, lssAddress) {
        _mint(initialAccount, initialBalance);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function transferInternal(address from, address to, uint256 value) public {
        _transfer(from, to, value);
    }

    function approveInternal(address owner, address spender, uint256 value) public {
        _approve(owner, spender, value);
    }
}