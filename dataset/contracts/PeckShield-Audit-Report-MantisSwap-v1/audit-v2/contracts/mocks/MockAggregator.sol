// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockAggregator {

    int256 valueUSD;    // in 8 decimals

    constructor (int256 _valueUSD) {
        valueUSD = _valueUSD;
    }
  
    function decimals() external view returns (uint8) {
        return 8;
    }

    function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) {
        answer = valueUSD;
    }
}