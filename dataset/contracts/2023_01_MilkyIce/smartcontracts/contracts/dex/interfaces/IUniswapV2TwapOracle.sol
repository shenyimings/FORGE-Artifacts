//SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

interface IUniswapV2TwapOracle {
  function update() external;

  function consult(address token, uint amountIn) external view returns (uint amountOut);

  function pair() external view returns (IUniswapV2Pair);

  function getObservedPrices(
    address tokenA
  ) external view returns (uint observedATokenPrice, uint observedBTokenPrice);

  function getPriceRatios(
    address denominatorToken
  ) external view returns (uint observedDenominatorTokenRatio, uint observedBTokenRatio);
}
