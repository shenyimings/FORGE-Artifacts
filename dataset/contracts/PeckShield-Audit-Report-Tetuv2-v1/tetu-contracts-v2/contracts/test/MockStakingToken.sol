// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../openzeppelin/ERC20Upgradeable.sol";
import "../interfaces/IGauge.sol";

contract MockStakingToken is ERC20Upgradeable {

  uint8 internal immutable _decimals;
  IGauge internal immutable gauge;

  constructor(
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    address gauge_
  )  {
    _decimals = decimals_;
    gauge = IGauge(gauge_);
    _init(name_, symbol_);
  }

  function _init(
    string memory name_,
    string memory symbol_
  ) internal initializer {
    __ERC20_init(name_, symbol_);
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }

  function mint(address to, uint amount) external {
    _mint(to, amount);
  }

  function _afterTokenTransfer(
    address from,
    address to,
    uint
  ) internal override {
    gauge.handleBalanceChange(from);
    gauge.handleBalanceChange(to);
  }
}
