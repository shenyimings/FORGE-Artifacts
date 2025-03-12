// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

interface AggregatorInterface {
    function latestAnswer() external view returns (int256);

    function latestTimestamp() external view returns (uint256);

    function latestMarketOpen() external view returns (bool);

    function latestRound() external view returns (uint256);

    function getAnswer(uint256 roundId) external view returns (int256);

    function getTimestamp(uint256 roundId) external view returns (uint256);

    function getMarketOpen(uint256 roundId) external view returns (bool);

    event AnswerUpdated(int256 indexed current, bool marketOpen, uint256 indexed roundId, uint256 updatedAt);
    event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}
