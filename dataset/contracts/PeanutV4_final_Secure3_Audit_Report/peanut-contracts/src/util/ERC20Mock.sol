// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20Mock is ERC20 {
    constructor() ERC20("ERC20Mock", "20MOCK") {
        this;
    }

    // mint function mints tokens to the specified address
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
