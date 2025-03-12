// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @notice Utility library for pairs.
 */
library PairLib {
  /**
   * @notice Returns tokens in ascending order by address.
   * @param token1 First token address
   * @param token2 Second token address
   */
  function getPairInOrder(
    address token1,
    address token2
  ) internal pure returns (address, address) {
    return token1 > token2 ? (token2, token1) : (token1, token2);
  }

  /**
   * @notice Calculates max amount of uniqe pairs for given amount of assets.
   * @param amountOfAssets Amount of assets to calculate max amount of pairs
   */
  function getMaxAmountOfPairs(uint256 amountOfAssets) internal pure returns (uint256) {
    if (amountOfAssets < 2) return 0;
    // Formula for combinations: C(n, k) = n! / (k!(n - k)!)
    // where n = amountOfAssets and k = 2 (pair consists of 2 assets)
    return _factorial(amountOfAssets) / (2 * _factorial(amountOfAssets - 2));
  }
}

function _factorial(uint x) pure returns (uint y) {
  if (x == 0) {
    return 1;
  } else {
    return x * _factorial(x - 1);
  }
}
