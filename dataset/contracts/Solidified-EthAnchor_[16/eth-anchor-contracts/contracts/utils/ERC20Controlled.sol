// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { Ownable } from "./Ownable.sol";

interface IERC20Controlled is IERC20 {
  function mint(address _to, uint256 _amount) external;

  function burn(uint256 _amount) external;

  function burnFrom(address _from, uint256 _amount) external;
}

contract ERC20Controlled is Context, Ownable, IERC20Controlled, ERC20 {
  using SafeMath for uint256;

  constructor(string memory _name, string memory _symbol)
    Ownable()
    ERC20(_name, _symbol)
  {}

  function mint(address _to, uint256 _amount) public override onlyOwner {
    _mint(_to, _amount);
  }

  function burn(uint256 _amount) public override {
    _burn(_msgSender(), _amount);
  }

  function burnFrom(address _from, uint256 _amount) public override {
    uint256 decreasedAllowance = allowance(_from, _msgSender()).sub(
      _amount,
      "ERC20: burn amount exceeds allowance"
    );

    _approve(_from, _msgSender(), decreasedAllowance);
    _burn(_from, _amount);
  }
}
