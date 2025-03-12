// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

/// @title IPriceFeeds
/// @author Polytrade
interface IPriceFeeds {
    /**
     * @notice Link Stable Address to ChainLink Aggregator
     * @dev Add a mapping stableAddress to aggregator
     * @param stable, address of the ERC-20 stable smart contract
     * @param aggregator, address of the aggregator to map with the stableAddress
     */
    function setStableAggregator(address stable, address aggregator) external;

    /**
     * @notice Get the price of the stableAddress against USD dollar
     * @dev Query Chainlink aggregator to get Stable/USD price
     * @param stableAddress, address of the stable to be queried
     * @return price of the stable against USD dollar
     */
    function getPrice(address stableAddress) external view returns (uint);

    /**
     * @notice Returns the decimal used for the stable
     * @dev Query Chainlink aggregator to get decimal
     * @param stableAddress, address of the stable to be queried
     * @return decimals of the USD
     */
    function getDecimals(address stableAddress) external view returns (uint);
}
