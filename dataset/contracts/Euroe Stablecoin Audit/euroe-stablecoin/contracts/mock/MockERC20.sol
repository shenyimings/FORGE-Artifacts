// SPDX-License-Identifier: MIT
// Used as some other regular ERC20 token in unit tests
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender, 100 * 10**decimals());
    }
}
