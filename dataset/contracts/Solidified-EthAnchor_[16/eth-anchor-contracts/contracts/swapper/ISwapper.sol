// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;

interface ISwapper {
  function swapToken(
    address _from,
    address _to,
    uint256 _amount,
    uint256 _minAmountOut,
    address _beneficiary
  ) external;
}
