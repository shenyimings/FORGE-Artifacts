// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./IPriceFeeds.sol";
import "./AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

/// @title PriceFeeds
/// @author Polytrade
contract PriceFeeds is IPriceFeeds, Ownable {
    uint public outdatedLimit;

    /// Mapping stableAddress to its USD Aggregator
    mapping(address => AggregatorV3Interface) public stableAggregators;

    /**
     * @notice Link Stable Address to ChainLink Aggregator
     * @dev Add a mapping stableAddress to aggregator
     * @param stable, address of the ERC-20 stable smart contract
     * @param aggregator, address of the aggregator to map with the stableAddress
     */
    function setStableAggregator(address stable, address aggregator)
        external
        onlyOwner
    {
        stableAggregators[stable] = AggregatorV3Interface(aggregator);
    }

    /**
     * @notice Set limit for a price feed to be outdated
     * @dev Add a mapping stableAddress to aggregator
     * @param limitInHours, limit (number of hours)
     */
    function setOutdatedLimit(uint limitInHours) external onlyOwner {
        outdatedLimit = 1 hours * limitInHours;
    }

    /**
     * @notice Get the price of the stableAddress against USD dollar
     * @dev Query Chainlink aggregator to get Stable/USD price
     * @param stableAddress, address of the stable to be queried
     * @return price of the stable against USD dollar
     */
    function getPrice(address stableAddress) public view returns (uint) {
        (, int price, , uint timestamp, ) = stableAggregators[stableAddress]
            .latestRoundData();
        require(
            block.timestamp - timestamp <= outdatedLimit,
            "Outdated pricing feed"
        );

        return uint(price);
    }

    /**
     * @notice Returns the decimal used for the stable
     * @dev Query Chainlink aggregator to get decimal
     * @param stableAddress, address of the stable to be queried
     * @return decimals of the USD
     */
    function getDecimals(address stableAddress) public view returns (uint) {
        return stableAggregators[stableAddress].decimals();
    }
}
