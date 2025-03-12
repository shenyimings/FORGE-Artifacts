// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Test20 is ERC20 {
    constructor() ERC20("Test20", "Symbol20") {
        _mint(msg.sender, 1000000000 * 10 ** 18);
    }
}
