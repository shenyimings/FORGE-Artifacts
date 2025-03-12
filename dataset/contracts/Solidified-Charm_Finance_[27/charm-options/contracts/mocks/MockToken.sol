// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20("Mock Token", "MOCK") {
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function setDecimals(uint8 decimals) external {
        _setupDecimals(decimals);
    }
}
