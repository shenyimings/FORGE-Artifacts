// contracts/MyERC20.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_, uint256 supply_, uint8 decimals_) ERC20(name_, symbol_) {
        require(decimals_ <= 18, "Invalid decimals");
        _decimals = decimals_;
        _mint(msg.sender, supply_);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}