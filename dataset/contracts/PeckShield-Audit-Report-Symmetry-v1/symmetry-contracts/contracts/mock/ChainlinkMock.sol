// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

// Chainlink mock contract for local test
contract ChainlinkMock {
    uint8 public decimals;
    uint80 public roundId;
    mapping(uint => int) public answers;
    mapping(uint => uint) public updateTime;

    constructor(uint8 _decimals) {
        decimals = _decimals;
    }

    function feed(int _answer, uint _updatedAt) external {
        ++roundId;
        answers[roundId] = _answer;
        updateTime[roundId] = _updatedAt;
    }

    function latestRoundData() external view returns (uint80, int, uint, uint, uint80) {
        require(roundId > 0, "ChainlinkMock: no price");
        return (roundId, answers[roundId], 0, updateTime[roundId], roundId);
    }
}
