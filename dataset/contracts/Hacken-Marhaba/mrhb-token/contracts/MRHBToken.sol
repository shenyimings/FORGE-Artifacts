// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./ERC20Burnable.sol";
import "./Ownable.sol";

contract MRHBToken is Ownable, ERC20Burnable {
  string private constant _name = "Marhaba DeFi";
  string private constant _symbol = "MRHB";

  constructor(uint256 initialSupply) public ERC20(_name, _symbol) {
    _mint(owner(), initialSupply);
  }
}