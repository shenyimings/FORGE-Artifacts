// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice DISCLAIMER: This is a mock ERC20 token for testing purposes only.
/// @dev Do not use in production.

contract ERC20Mock is ERC20 {
    uint8 private immutable __decimals;

    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _amount) ERC20(_name, _symbol) {
        __decimals = _decimals;
        _mint(msg.sender, _amount);
    }

    function decimals() public view override returns (uint8) {
        return __decimals;
    }

    function mint(uint256 _amount) public {
        _mint(msg.sender, _amount * (10 ** __decimals));
    }
}
