// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockAmmToken is ERC20 {
    constructor() ERC20("MockAmmToken", "AMM") {}

    function mintForTesting(address user, uint256 amount) external {
        _mint(user, amount);
    }
}
