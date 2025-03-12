// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

contract ChainLinkOracleV3Mock {
  int256 public answer;

  function setLatestAnswer(int256 _answer) external {
    answer = _answer;
  }

  function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
    return (0, answer, 0, 0, 0);
  }
}
