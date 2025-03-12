//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import './ERC20.sol';

contract ElemonToken is ERC20 {
    constructor() ERC20("Elemon Token", "ELMON", 2000000000000000000000000000){}
}