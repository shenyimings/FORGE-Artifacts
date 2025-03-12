// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { ERC20 } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import { ERC20Burnable } from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import { AccessControl } from '@openzeppelin/contracts/access/AccessControl.sol';
import { ERC20Permit } from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';

/// @title Mock ERC20 with a 1% fee on transfer for testing purposes
contract TransferFeeTokenMock is ERC20, ERC20Burnable, AccessControl, ERC20Permit {
  constructor(
    string memory _name,
    string memory _symbol,
    uint256 _initialSupply
  ) ERC20(_name, _symbol) ERC20Permit(_name) {
    _mint(_msgSender(), _initialSupply);
    _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }

  function _update(address from, address to, uint256 amount) internal virtual override {
    uint256 fee = amount / 100; // 1% fee on transfer
    super._update(from, address(this), fee);
    super._update(from, to, amount - fee);
  }

  function withdrawTransferFees(address to) public onlyRole(DEFAULT_ADMIN_ROLE) {
    uint256 balance = balanceOf(address(this));
    transfer(to, balance);
  }
}
