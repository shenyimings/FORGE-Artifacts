// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

contract ChainlinkAggregatorMock {
    int256 private _latestAnswer;
    constructor() {}

    function setLatestAnswer(int256 answer) external {
        _latestAnswer = answer;
    }

    function latestAnswer() external view returns (int256) {
        return _latestAnswer;
    }
}