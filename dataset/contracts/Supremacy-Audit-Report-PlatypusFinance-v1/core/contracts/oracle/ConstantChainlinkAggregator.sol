// SPDX-License-Identifier: GPL-3.0
import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

pragma solidity 0.8.9;

// Always returns 1 in 8 d.p as price
contract ConstantChainlinkAggregator is AggregatorV3Interface {
    int256 public latestAnswer = 1e8;

    function latestTimestamp() external view returns (uint256) {
        return block.timestamp;
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
        return (0, latestAnswer, 0, block.timestamp, 0);
    }

    function version() external pure override returns (uint256) {
        return 0;
    }

    function decimals() external pure override returns (uint8) {
        return 8;
    }

    function description() external pure override returns (string memory) {
        return 'Constant chainlink feed';
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
