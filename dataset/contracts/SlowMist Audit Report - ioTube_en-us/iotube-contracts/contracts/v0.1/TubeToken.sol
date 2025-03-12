// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TubeToken is ERC20 {
    constructor() ERC20("Tube Token", "TT") {
        _mint(msg.sender, 10_000_000_000 * 10**18);
    }
}
