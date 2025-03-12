// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) public ERC20(name, symbol) {
        _mint(msg.sender, supply);
    }

    function mintTokens(uint256 _amount) external {
        _mint(msg.sender, _amount);
    }

    function mintReward(address _user, uint256 _amount) external {
        _mint(_user, _amount);
    }
}
