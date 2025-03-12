// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PBXToken is Ownable, ERC20Burnable {
    string private constant _NAME = "Paribus";
    string private constant _SYMBOL = "PBX";

    constructor(uint256 initialSupply) public ERC20(_NAME, _SYMBOL) {
        _mint(owner(), initialSupply);
    }
}
