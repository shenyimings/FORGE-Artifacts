// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { ERC20 } from "@solmate/Tokens/ERC20.sol";

contract TestERC20 is ERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol, _decimals) { }

    function mint() public {
        _mint(msg.sender, 1_000_000 * 10 ** decimals);
    }

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}
