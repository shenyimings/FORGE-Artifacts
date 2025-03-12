// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

//Note: Token is Mintable due to the ERC20Capped Inheritence
contract payMEToken is ERC20Capped, Ownable, ERC20Pausable {

  using SafeMath for uint256;

  uint256 constant MAXIMUMSUPPLY = 10000000000000000000000000000;

  constructor() ERC20("PMe", "PMe") ERC20Capped(MAXIMUMSUPPLY) {
      _mint(msg.sender, MAXIMUMSUPPLY);
  }

  function _mint(address account, uint256 amount) override(ERC20, ERC20Capped) internal  {
    super._mint(account, amount);
  }

  function _beforeTokenTransfer(address from, address to, uint256 amount) override(ERC20, ERC20Pausable) internal {
    super._beforeTokenTransfer(from, to, amount);
  }

}