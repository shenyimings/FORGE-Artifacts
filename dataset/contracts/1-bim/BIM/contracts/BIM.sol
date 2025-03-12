// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract BIM is ERC20, ERC20Burnable {
    constructor() ERC20("BIM", "BIM") {
        _mint(0x115A40E5F42a9369797643a65220411C533da38c, 314000000 * 10 ** decimals());
    }
}
