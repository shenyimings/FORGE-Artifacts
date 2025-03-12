// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

contract AggregatorInterfaceETH {
  int256 value = 153432000000;

  function latestAnswer() public view virtual returns (int256) {
    return value;
  }

  function latestRoundData()
    public
    view
    virtual
    returns (
      uint80,
      int256,
      uint256,
      uint256,
      uint80
    )
  {
    return (
      153432000000,
      value,
      1616543796,
      1616543819,
      153432000000
    );
  }

  event AnswerUpdated(
    int256 indexed current,
    uint256 indexed roundId,
    uint256 timestamp
  );
  event NewRound(
    uint256 indexed roundId,
    address indexed startedBy,
    uint256 startedAt
  );
}
