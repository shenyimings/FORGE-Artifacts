// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockRewardToken is ERC20 {
    constructor () ERC20("Reward Token", "REWARD") {
        _mint(msg.sender, 10000 ** uint(decimals()));
    }
}
