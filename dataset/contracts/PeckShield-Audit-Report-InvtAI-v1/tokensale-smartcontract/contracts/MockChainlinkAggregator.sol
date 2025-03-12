// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

contract MockChainlinkAggregator is AggregatorV3Interface {
  address public owner;
  int256 public price;
  uint8 internal _decimals;

  modifier onlyOwner() {
    require(msg.sender == owner, "only owner can");
    _;
  }

  constructor(
    uint8 __decimals,
    int256 _price
  ) public {
    _decimals = __decimals;
    owner = msg.sender;
    price = _price;
  }

  function setPrice(int256 _price) external onlyOwner {
    price = _price;
  }

  function decimals()
    external
    view
    override
    returns (
      uint8
    ) {
      return _decimals;
    }

  function description()
    external
    view
    override
    returns (
      string memory
    ) {
      return "Mock Chainlink Aggregator";
    }

  function version()
    external
    view
    override
    returns (
      uint256
    ) {
      return 1;
    }

  function getRoundData(
    uint80 _roundId
  )
    external
    view
    override
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) {
      return (_roundId, price, 1, 1, 1);
    }

  function latestRoundData()
    external
    view
    override
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) {
      return (1, price, 1, 1, 1);
    }

}
