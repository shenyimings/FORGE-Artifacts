// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GMRX is ERC20 {
    constructor() ERC20("Matic Gaimin Token", "M_GMRX") {
        _mint(_msgSender(), 100000000000 * (10 ** uint256(decimals())));
    }
}
