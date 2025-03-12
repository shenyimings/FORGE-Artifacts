// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LiquidityValueCalculator, IUniswapV2TwapOracle} from './LiquidityValueCalculator.sol';

contract LiquidityValueCalculatorMock {
  /// @dev Computes the value for a given liquidity share in terms of the underlying tokens on a Uniswap V2 pair.
  function calculateLiquidityValue(
    IUniswapV2TwapOracle _oracle,
    address _tokenA,
    uint _amountOfLPTokens
  ) public view returns (uint tokenAAmount, uint tokenBAmount) {
    return
      LiquidityValueCalculator.calculateLiquidityValue(
        _oracle,
        _tokenA,
        _amountOfLPTokens
      );
  }
}
