// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

import "../../lib/chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SequencerUptimeFeed is AggregatorV3Interface {
    function decimals() external pure returns (uint8) {
        return 0;
    }

    function description() external pure returns (string memory) {
        return "";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 _roundId)
        external
        pure
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, 0, 0, 0, 0);
    }

    function latestRoundData()
        external
        pure
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, 0, 0, 0, 0);
    }
}
