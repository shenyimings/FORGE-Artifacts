// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "../../src/interfaces/chainlink/AggregatorV3Interface.sol";

contract AggregatorV3 is AggregatorV3Interface {

    function decimals() external view override returns (uint8) {
        return 18;
    }

    function description() external view override returns (string memory) {
        return "Aggregator V3";
    }

    function version() external view override returns (uint256) {
        return 3;
    }

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId = 18446744073709552178;
        answer = 998191525919078400;
        startedAt = 1677768839;
        updatedAt = 1677768839;
        answeredInRound = 18446744073709552178; 
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId = 18446744073709552178;
        answer = 998191525919078400;
        startedAt = 1677768839;
        updatedAt = 1677768839;
        answeredInRound = 18446744073709552178;
    }
}