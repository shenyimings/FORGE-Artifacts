// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.5.17;

import "@chainlink/contracts/src/v0.5/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.5/interfaces/FlagsInterface.sol";
import "./StablecoinsPriceOracle.sol";

contract ChainlinkPriceOracle is StablecoinsPriceOracle {
    /// @notice underlying address => underlying asset price data feed
    mapping(address => address) public chainlinkDataFeeds;

    function isTokenSupported(address token) public view returns (bool) {
        return StablecoinsPriceOracle.isTokenSupported(token) || chainlinkDataFeeds[token] != address(0);
    }

    function getPriceOfUnderlying(address token, uint decimals) public view returns (uint) {
        require(isTokenSupported(token), "TOKEN_NOT_SUPPORTED");
        if (StablecoinsPriceOracle.isTokenSupported(token)) return StablecoinsPriceOracle.getPriceOfUnderlying(token, decimals);

        AggregatorV3Interface priceFeed = AggregatorV3Interface(chainlinkDataFeeds[token]);
        (uint80 roundID, int256 price, uint256 updatedAt, uint256 timeStamp, uint80 answeredInRound) = priceFeed.latestRoundData();
        require(price > 0, "invalid chainlink answer: price");
        require(timeStamp > 0, "invalid chainlink answer: timestamp");
        require(answeredInRound >= roundID, "invalid chainlink answer: answeredInRound");
        require(subabs(block.timestamp, updatedAt) < 86400 * 1.1, "invalid chainlink answer: updatedAt"); // chainlink heartbeat is 86400s or lower on all chains (we multiply by some slippage factor)

        return adjustDecimals(priceFeed.decimals(), decimals, uint(price));
    }

    /**
      * @return abs(a - b)
      */
    function subabs(uint a, uint b) internal pure returns (uint) {
        return a > b ? a - b : b - a;
    }
}

contract L2ChainlinkPriceOracle is ChainlinkPriceOracle {
    /// @notice internal Chainlink flag to indicate that the sequencer is offline
    address internal FLAG_SEQ_OFFLINE;

    FlagsInterface internal chainlinkFlags;

    function getPriceOfUnderlying(address token, uint decimals) public view returns (uint) {
        bool isRaised = chainlinkFlags.getFlag(FLAG_SEQ_OFFLINE);
        if (isRaised) {
            // If flag is raised we shouldn't perform any critical operations
            revert("Chainlink feeds are not being updated");
        }

        return ChainlinkPriceOracle.getPriceOfUnderlying(token, decimals);
    }
}
