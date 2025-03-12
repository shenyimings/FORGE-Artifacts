// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OwnableToken is ERC20, Ownable  {

  constructor(string memory name, string memory symbol) ERC20(name, symbol) { }

  function mint(address account, uint amount) public onlyOwner {
    _mint(account, amount);
  }

  function burn(address account, uint amount) public onlyOwner {
    _burn(account, amount);
  }

}