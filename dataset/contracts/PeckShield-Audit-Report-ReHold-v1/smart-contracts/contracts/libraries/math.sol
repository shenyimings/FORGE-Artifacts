// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

library Math {
  uint32 constant PERCENT_DECIMALS = 10 ** 8;

  function percent(uint256 amount, uint256 _percent) internal pure returns (uint256) {
    return (amount * _percent) / PERCENT_DECIMALS;
  }
}
