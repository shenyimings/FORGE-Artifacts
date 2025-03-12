// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../utils/TrustCaller.sol";

contract sdToken is ERC20, Ownable, TrustCaller {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    }

    function mint(address account, uint256 amount) external onlyTrustCaller {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external onlyTrustCaller {
        _burn(account, amount);
    }
} 