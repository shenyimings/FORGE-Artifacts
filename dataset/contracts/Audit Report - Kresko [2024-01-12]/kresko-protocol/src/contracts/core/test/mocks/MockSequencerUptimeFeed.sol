// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

contract MockSequencerUptimeFeed {
    uint256 internal __startedAt;
    uint256 internal __updatedAt;
    int256 internal __answer;

    constructor() {
        __startedAt = block.timestamp;
        __updatedAt = block.timestamp;
    }

    function setAnswers(int256 _answer, uint256 _startedAt, uint256 _updatedAt) external {
        __startedAt = _startedAt != 0 ? _startedAt : block.timestamp;
        __updatedAt = _updatedAt != 0 ? _updatedAt : block.timestamp;
        __answer = _answer;
    }

    /// @notice 0 = up, 1 = down
    function setAnswer(int256 _answer) external {
        if (_answer != __answer) {
            __startedAt = block.timestamp;
            __answer = _answer;
        }
        __updatedAt = block.timestamp;
    }

    function latestRoundData()
        public
        view
        virtual
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, __answer, __startedAt, updatedAt, 0);
    }
}
