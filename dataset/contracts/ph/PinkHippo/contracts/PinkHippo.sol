// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract PinkHippo is ERC20 , Ownable {
    constructor() ERC20("Pink Hippo", "PH") {
        _mint(msg.sender, 10000000000 * 10 ** decimals());
    }
}
