// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FaucetToken is ERC20 {
    
    constructor(string memory name, string memory symbol, uint8 decimals, uint256 initialSupply) ERC20(name, symbol) public {
        _setupDecimals(decimals);
        _mint(msg.sender, initialSupply);
    }

    function faucet(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
