//SPDX-License-Identifier: MIT
pragma solidity 0.6.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockCollateral is ERC20 {
    constructor(string memory name, string memory symbol) public ERC20(name, symbol) { }

    function faucet(address recipient, uint256 amount) external {
        _mint(recipient, amount);
    }
}
