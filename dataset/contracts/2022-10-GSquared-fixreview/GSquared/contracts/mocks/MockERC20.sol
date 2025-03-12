// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.10;

import "../solmate/src/tokens/ERC20.sol";

abstract contract MockERC20 is ERC20 {
    mapping(address => bool) internal claimed;

    function faucet(uint256 amount) external virtual;

    function mint(address account, uint256 amount) external {
        require(account != address(0), "Account is empty.");
        require(amount > 0, "amount is less than zero.");
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        require(account != address(0), "Account is empty.");
        require(amount > 0, "amount is less than zero.");
        _burn(account, amount);
    }
}
