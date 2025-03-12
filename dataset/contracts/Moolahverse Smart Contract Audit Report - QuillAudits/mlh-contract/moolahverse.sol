// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts@5.0.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@5.0.0/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts@5.0.0/token/ERC20/extensions/ERC20Permit.sol";

contract Moolahverse is ERC20, ERC20Burnable, ERC20Permit {
    constructor() ERC20("Moolahverse", "MLH") ERC20Permit("Moolahverse") {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }
}
