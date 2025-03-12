// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.17;

import "@chainlink/contracts/src/v0.5/interfaces/AggregatorV3Interface.sol";

contract ChainlinkAggregatorV3Mock is AggregatorV3Interface {
  function decimals() external override view returns (uint8) {
    return decimalsMock;
  }

  function description() external override view returns (string memory) { revert("not implemented"); }
  function version() external override view returns (uint256) { revert("not implemented"); }

  int256 answerMock;
  uint8 decimalsMock;

  constructor(int256 _answer, uint8 _decimals) public {
    answerMock = _answer;
    decimalsMock = _decimals;
  }

  function getRoundData(uint80) external override view returns (uint80, int256, uint256, uint256, uint80) {
    revert("not implemented");
  }

  function latestRoundData() external override view returns (uint80, int256, uint256, uint256, uint80) {
    return (42, answerMock, block.timestamp - 2000, block.timestamp + 1000, 42);
  }
}
