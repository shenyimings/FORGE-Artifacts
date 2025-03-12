// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockToken is ERC20 , Ownable {
  uint8 private _decimal;

  constructor(string memory _name_, string memory _symbol_,uint8 _decimals_) ERC20(_name_,_symbol_) {
    _decimal = _decimals_;
  }

  function decimals() public view override returns (uint8) {
    return _decimal;
  }

  function mint(address to, uint256 amount) public onlyOwner {
    _mint(to, amount);
  }

}
