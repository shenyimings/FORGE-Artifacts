// DO NOT DEPLOY TO MAINNET
// This is a mock token meant to be used in beta testing
// The owner will faucet a certain amount of tokens for the whitelisted users
// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract OwnableTestERC20 is ERC20, Ownable {
    uint8 public d;

    constructor(
        string memory name,
        string memory symbol,
        uint8 _decimals,
        uint256 supply
    ) ERC20(name, symbol) {
        d = _decimals;
        _mint(msg.sender, supply);
    }

    function decimals() public view override returns (uint8) {
        return d;
    }

    function faucet(address beneficiary, uint256 amount) external onlyOwner {
        require(beneficiary != address(0));
        _mint(beneficiary, amount);
    }

    // sets the balance of the address
    // this mints/burns the amount depending on the current balance
    function setBalance(address to, uint256 amount) external onlyOwner {
        uint256 old = balanceOf(to);
        if (old < amount) {
            _mint(to, amount - old);
        } else if (old > amount) {
            _burn(to, old - amount);
        }
    }
}
