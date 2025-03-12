// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @custom:security-contact support@ycryptobank.com
contract YourCryptoBank is ERC20, ERC20Burnable, ERC20Permit, ERC20FlashMint, Ownable {
    constructor(address initialOwner)
        ERC20("Your Crypto Bank", "YCB")
        ERC20Permit("Your Crypto Bank")
        Ownable(initialOwner)
    {
        _mint(msg.sender, 4000000 * 10 ** decimals());
    }
}