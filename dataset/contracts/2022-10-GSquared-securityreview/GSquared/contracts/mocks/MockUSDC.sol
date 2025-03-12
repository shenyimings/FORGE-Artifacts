// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.10;

import "./MockERC20.sol";

contract MockUSDC is MockERC20 {
    constructor() ERC20("USDC", "USDC", 6) {}

    function faucet(uint256 amount) external override {
        require(!claimed[msg.sender], "Already claimed");
        claimed[msg.sender] = true;
        _mint(msg.sender, amount);
    }
}
