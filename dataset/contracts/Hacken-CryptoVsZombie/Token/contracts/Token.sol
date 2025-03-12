//SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/**
 * @title Token
 * @author gotbit
 */

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Token is ERC20 {
    uint256 public totalSupply_ = 1_000_000_000 ether;

    constructor() ERC20('CryptoVsZombie', 'CVZ') {
        _mint(msg.sender, totalSupply_);
    }
}
