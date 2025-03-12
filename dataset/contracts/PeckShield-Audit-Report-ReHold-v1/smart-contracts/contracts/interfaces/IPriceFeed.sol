// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

interface IPriceFeed {
  struct Aggregator {
    AggregatorV2V3Interface aggregator;
    uint256 decimals;
    uint256 tokenDecimals;
  }

  struct TokenAggregator {
    address token;
    address aggregator;
  }

  function currentCrossPrice(address baseToken, address quoteToken) external returns (uint256);

  function historicalCrossPrice(
    address baseToken,
    uint80 baseRoundId,
    address quoteToken,
    uint80 quoteRoundId,
    uint256 timestamp
  ) external returns (uint256);

  function updateAggregator(address token, address aggregator) external;

  function aggregator(address token) external view returns (AggregatorV2V3Interface);

  function aggregators() external view returns (TokenAggregator[] memory tokenAggregators);
}
