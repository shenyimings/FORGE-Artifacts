// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract MockFeedRegistry is Ownable {
    mapping(address => mapping(address => address)) feeds;

    /**
     * @notice represents the number of decimals the aggregator responses represent.
     */
    function decimals(address base, address quote)
        external
        view
        returns (uint8)
    {
        AggregatorV2V3Interface aggregator = _getFeed(base, quote);
        require(address(aggregator) != address(0), 'Feed not found');
        return aggregator.decimals();
    }

    function latestRoundData(address base, address quote)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        AggregatorV2V3Interface aggregator = _getFeed(base, quote);
        require(address(aggregator) != address(0), 'Feed not found');
        (roundId, answer, startedAt, updatedAt, answeredInRound) = aggregator
            .latestRoundData();
    }

    function getFeed(address base, address quote)
        external
        view
        returns (AggregatorV2V3Interface aggregator)
    {
        aggregator = _getFeed(base, quote);
        require(address(aggregator) != address(0), 'Feed not found');
    }

    function setFeed(
        address base,
        address quote,
        address aggregator
    ) external onlyOwner {
        feeds[base][quote] = aggregator;
    }

    function _getFeed(address base, address quote)
        internal
        view
        returns (AggregatorV2V3Interface aggregator)
    {
        aggregator = AggregatorV2V3Interface(feeds[base][quote]);
    }
}
