// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { ERC20 } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import { ERC20Burnable } from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import { AccessControl } from '@openzeppelin/contracts/access/AccessControl.sol';
import { ERC20Permit } from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import { FundSwap } from '../FundSwap.sol';

/// @title Reentrant ERC20 mintable token for testing purposes
contract ReentrantERC20 is ERC20, ERC20Burnable, AccessControl, ERC20Permit {
  bytes32 public constant MINTER_ROLE = keccak256('MINTER_ROLE');

  address public deployer;
  FundSwap public fundswap;
  bool public isDuringReentrancy;

  constructor(
    FundSwap _fundswap
  ) ERC20('ReentrantERC20', 'REC20') ERC20Permit('ReentrantERC20') {
    _mint(_msgSender(), 10 * 1e18);
    _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _grantRole(MINTER_ROLE, _msgSender());
    deployer = _msgSender();
    fundswap = _fundswap;
  }

  function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
    _mint(to, amount);
  }

  function _update(address from, address to, uint256 value) internal virtual override {
    super._update(from, to, value);
    if (to == deployer && !isDuringReentrancy) {
      isDuringReentrancy = true;
      fundswap.cancelOrder(0);
    }
    isDuringReentrancy = false;
  }
}
