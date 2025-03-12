// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../openzeppelin/ERC20Upgradeable.sol";

contract MockToken is ERC20Upgradeable {

  uint8 internal _decimals;

  constructor(
    string memory name_,
    string memory symbol_,
    uint8 decimals_
  )  {
    _init(name_, symbol_, decimals_);
  }

  function _init(
    string memory name_,
    string memory symbol_,
    uint8 decimals_
  ) internal initializer {
    __ERC20_init(name_, symbol_);
    _decimals = decimals_;
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }

  function mint(address to, uint amount) external {
    _mint(to, amount);
  }

  function burn(address from, uint amount) external {
    _burn(from, amount);
  }
}
