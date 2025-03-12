pragma solidity 0.6.6;

// SPDX-License-Identifier: Unlicensed

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract HTEthUsd is ERC20Burnable, Ownable {
    
    constructor () ERC20("HODL ERC20 Token, Ethereum, US Dollar", "HTETHUSD") public {
    	_setupDecimals(18);
    }
    
    function mint(address user, uint amount) external onlyOwner { // TODO: Check ownership graph
        _mint(user, amount);
    }
}
