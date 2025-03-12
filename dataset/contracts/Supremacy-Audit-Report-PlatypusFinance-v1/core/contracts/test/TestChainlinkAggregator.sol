// SPDX-License-Identifier: GPL-3.0
import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

pragma solidity 0.8.9;

contract TestChainlinkAggregator is AggregatorV3Interface {
    int256 private _latestAnswer;
    uint256 private _latestTimestamp;

    function setLatestAnswer(int256 latestAnswer_, uint256 latestTimestamp_) external {
        _latestAnswer = latestAnswer_;
        _latestTimestamp = latestTimestamp_;
    }

    function latestAnswer() external view returns (int256) {
        return _latestAnswer;
    }

    function latestTimestamp() external view returns (uint256) {
        return _latestTimestamp;
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        return (0, _latestAnswer, 0, block.timestamp, 0);
    }

    function version() external pure override returns (uint256) {
        return 0;
    }

    function decimals() external pure override returns (uint8) {
        return 8;
    }

    function description() external pure override returns (string memory) {
        return 'Mock chainlink feed';
    }

    function getRoundData(uint80)
        external
        pure
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, 0, 0, 0, 0);
    }
}
