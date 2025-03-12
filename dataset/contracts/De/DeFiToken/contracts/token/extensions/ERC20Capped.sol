// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';


abstract contract ERC20Capped is ERC20 {
  uint256 private _cap;

  error CapZeroErr();
  error CapLowErr();
  error CapExceededErr();

  constructor(uint256 cap_) {
    if (cap_ == 0) revert CapZeroErr();
    _cap = cap_;
  }

  function cap()
    public
    view
    virtual
    returns (uint256)
  {
    return _cap;
  }

  function _setCap(uint256 amount)
    internal
  {
    if (_cap > amount) revert CapLowErr();
    _cap = amount;
  }

  function _mint(address account, uint256 amount)
    internal
    virtual
    override
  {
    if (ERC20.totalSupply() + amount > cap()) revert CapExceededErr();
    super._mint(account, amount);
  }
}
