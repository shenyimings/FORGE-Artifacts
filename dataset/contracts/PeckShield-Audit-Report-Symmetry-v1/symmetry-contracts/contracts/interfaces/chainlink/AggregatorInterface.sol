// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface AggregatorInterface {
    function latestAnswer() external view returns (int);

    function latestTimestamp() external view returns (uint);

    function latestRound() external view returns (uint);

    function getAnswer(uint roundId) external view returns (int);

    function getTimestamp(uint roundId) external view returns (uint);

    event AnswerUpdated(int indexed current, uint indexed roundId, uint updatedAt);

    event NewRound(uint indexed roundId, address indexed startedBy, uint startedAt);
}
