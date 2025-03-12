// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract U2V_BSC is ERC20, Ownable {
    constructor() ERC20("U2V_BSC", "U2V_BSC") {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }
}