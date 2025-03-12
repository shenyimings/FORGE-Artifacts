// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract MetaLand_Token is ERC20, ERC20Burnable {
    constructor() ERC20("Meta Land Play", "MLP") {
        _mint(msg.sender, 30000000 * 10 ** decimals());
    }
}
