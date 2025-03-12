// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.0;

contract OwnableToken is ERC20, Ownable {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address account, uint amount) public onlyOwner {
        _mint(account, amount);
    }
}

contract AprWarCoin is OwnableToken {
    constructor() OwnableToken("Apr War Coin", "AWC") {}
}
