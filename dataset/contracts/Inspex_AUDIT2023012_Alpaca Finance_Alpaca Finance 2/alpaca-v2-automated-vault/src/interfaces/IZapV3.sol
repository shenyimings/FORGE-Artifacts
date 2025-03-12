// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

interface IZapV3 {
  struct CalcParams {
    address pool;
    uint256 amountIn0;
    uint256 amountIn1;
    int24 tickLower;
    int24 tickUpper;
  }

  function calc(CalcParams calldata params)
    external
    returns (uint256 swapAmount, uint256 expectAmountOut, bool isZeroForOne);
}
