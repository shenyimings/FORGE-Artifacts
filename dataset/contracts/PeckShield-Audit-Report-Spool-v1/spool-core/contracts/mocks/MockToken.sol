// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../external/@openzeppelin/token/ERC20/ERC20.sol";

import "./interfaces/IERC20Mintable.sol";
// TEST
contract MockToken is IERC20Mintable, ERC20 {
    uint8 private immutable _decimals;
    constructor(
        string memory _symbol,
        string memory _name,
        uint8 decimals_
    ) ERC20(_symbol, _name) {
        _decimals = decimals_;
        _mint(msg.sender, 1_000_000_000 * (10 ** decimals_));
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address account, uint256 amount) public override {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public override {
        _burn(account, amount);
    }
}
