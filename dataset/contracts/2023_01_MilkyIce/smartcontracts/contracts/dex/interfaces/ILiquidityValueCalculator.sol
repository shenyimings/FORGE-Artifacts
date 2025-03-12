// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ILiquidityValueCalculator {
  function computeLiquidityShareValue(
    uint amountOfLPTokens,
    address tokenA,
    address tokenB
  ) external returns (uint tokenAAmount, uint tokenBAmount);
}
