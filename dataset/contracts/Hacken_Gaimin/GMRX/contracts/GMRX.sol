// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GMRX is ERC20 {
    constructor() ERC20("Gaimin Token", "GMRX") {
        _mint(_msgSender(), 100000000000 * (10 ** uint256(decimals())));
    }
}
