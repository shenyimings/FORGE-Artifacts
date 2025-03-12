// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {ERC20} from '../dependencies/openzeppelin/contracts/ERC20.sol';
import {PermitForERC20} from './PermitForERC20.sol';

abstract contract ERC20WithPermit is ERC20, PermitForERC20 {
  constructor(
    string memory name,
    string memory symbol,
    uint8 decimals
  ) public ERC20(name, symbol, decimals) PermitForERC20() {}

  function _approveByPermit(
    address owner,
    address spender,
    uint256 amount
  ) internal override {
    _approve(owner, spender, amount);
  }

  function _getPermitDomainName() internal view override returns (bytes memory) {
    return bytes(super.name());
  }
}
