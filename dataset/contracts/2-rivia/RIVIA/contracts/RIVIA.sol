// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @custom:security-contact thewitchergamecoin@gmail.com
contract RIVIA is ERC20, ERC20Burnable, Ownable {
    constructor(
        address payable treasureAddress
    ) ERC20("The Witcher Game", "RIVIA") {
        _mint(treasureAddress, 1000000000000000 * 10 ** decimals());
        require(treasureAddress != address(0), "Treasure is the zero address");
        _transferOwnership(treasureAddress);
    }
}
