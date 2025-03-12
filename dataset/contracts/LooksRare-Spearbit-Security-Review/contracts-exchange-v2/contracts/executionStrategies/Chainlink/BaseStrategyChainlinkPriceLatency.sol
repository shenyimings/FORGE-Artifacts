// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

/**
 * @title BaseStrategyChainlinkPriceLatency
 * @notice This contract allows the owner to define the maximum acceptable Chainlink price latency.
 * @author LooksRare protocol team (ðŸ‘€,ðŸ’Ž)
 */
contract BaseStrategyChainlinkPriceLatency is OwnableTwoSteps {
    /**
     * @notice Maximum latency accepted after which
     *         the execution strategy rejects the retrieved price.
     */
    uint256 public maxLatency;

    /**
     * @notice It is emitted when the maximum Chainlink price latency is updated.
     * @param newMaxLatency New maximum Chainlink price latency
     */
    event MaxLatencyUpdated(uint256 newMaxLatency);

    /**
     * @notice It is returned if the Chainlink price is invalid (e.g. negative).
     */
    error InvalidChainlinkPrice();

    /**
     * @notice It is returned if the latency tolerance is set too high (i.e. greater than 3,600 sec).
     */
    error LatencyToleranceTooHigh();

    /**
     * @notice It is returned if the current block time relative to the latest price's update time is greater than the latency tolerance.
     */
    error PriceNotRecentEnough();

    /**
     * @notice Constructor
     * @param _owner Owner address
     */
    constructor(address _owner) OwnableTwoSteps(_owner) {}

    /**
     * @notice This function allows the owner to update the maximum Chainlink price latency.
     *         It cannot be higher than 3,600 as Chainlink will at least update the price every 3,600 seconds,
     *         provided ETH's price does not deviate more than 0.5%.
     * @param newMaxLatency Maximum Chainlink price latency (in seconds)
     * @dev Only callable by owner.
     */
    function updateMaxLatency(uint256 newMaxLatency) external onlyOwner {
        if (newMaxLatency > 3_600) revert LatencyToleranceTooHigh();
        maxLatency = newMaxLatency;
        emit MaxLatencyUpdated(newMaxLatency);
    }
}
