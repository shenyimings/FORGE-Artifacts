// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./FaucetToken.sol";

contract FaucetWETH is FaucetToken {
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);

    constructor(string memory _name, string memory _symbol, uint8 __decimals) FaucetToken(_name, _symbol, __decimals) {}

    fallback() external payable {
        deposit();
    }

    receive() external payable {}

    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint wad) public {
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }
}
