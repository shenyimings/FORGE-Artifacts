// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function test_mock() external pure {}

    function mint(address receiver, uint256 amount) external {
        _mint(receiver, amount);
    }
}
