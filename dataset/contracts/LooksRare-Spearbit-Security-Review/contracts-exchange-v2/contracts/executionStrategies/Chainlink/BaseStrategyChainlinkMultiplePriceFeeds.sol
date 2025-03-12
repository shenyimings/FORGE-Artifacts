// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Dependencies
import {BaseStrategyChainlinkPriceLatency} from "./BaseStrategyChainlinkPriceLatency.sol";

/**
 * @title BaseStrategyChainlinkMultiplePriceFeeds
 * @notice This contract allows a strategy to store Chainlink price feeds for price retrieval.
 * @author LooksRare protocol team (ðŸ‘€,ðŸ’Ž)
 */
contract BaseStrategyChainlinkMultiplePriceFeeds is BaseStrategyChainlinkPriceLatency {
    /**
     * @notice This maps the collection address to a Chainlink price feed address.
     */
    mapping(address => address) public priceFeeds;

    /**
     * @notice It is returned if the price feed for a collection is already set.
     * @dev This error can only be retrieved by owner operation.
     */
    error PriceFeedAlreadySet();

    /**
     * @notice It is returned when the price feed is not available.
     */
    error PriceFeedNotAvailable();

    /**
     * @notice Emitted when a collection's price feed address is updated
     * @param collection NFT collection address
     * @param priceFeed Chainlink price feed address
     */
    event PriceFeedUpdated(address indexed collection, address indexed priceFeed);

    /**
     * @notice Constructor
     * @param _owner Owner address
     */
    constructor(address _owner) BaseStrategyChainlinkPriceLatency(_owner) {}

    /**
     * @notice This function allows the owner to set an NFT collection's Chainlink price feed address.
     * @dev Only callable by owner.
     *      Once the price feed is set for a collection, it is not possible to adjust it after.
     * @param _collection NFT collection address
     * @param _priceFeed Chainlink price feed address
     */
    function setPriceFeed(address _collection, address _priceFeed) external onlyOwner {
        if (priceFeeds[_collection] != address(0)) {
            revert PriceFeedAlreadySet();
        }

        priceFeeds[_collection] = _priceFeed;

        emit PriceFeedUpdated(_collection, _priceFeed);
    }
}
