// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Vidya is ERC20 {
    constructor() ERC20("Vidya", "Vidya") {
        _mint(msg.sender, 100000000 * 10**18);
    }
}
