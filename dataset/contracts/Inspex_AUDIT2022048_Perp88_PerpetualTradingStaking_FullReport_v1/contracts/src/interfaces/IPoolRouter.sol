// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IPoolRouter {
  function swap(
    address pool,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 minAmountOut,
    address receiver
  ) external returns (uint256);
}
