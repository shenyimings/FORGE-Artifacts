// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./lib/BEP20.sol";

contract Token is BEP20 {
    constructor(string memory _name, string memory _symbol, uint256 _initialSupply) public BEP20(_name, _symbol) {
        _mint(msg.sender, _initialSupply * 10 ** uint256(decimals));
    }
}
