// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GaryToken is ERC20, Ownable {
    constructor() ERC20("Gary Token", "GARY") {
        _mint(msg.sender, 8888888888 * 10 ** decimals());
    }
}