// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../../../oracle/AggregatorV3Interface.sol";

contract ChainlinkUSDTUSDPriceConsumer {

    AggregatorV3Interface internal priceFeed;


    constructor () public {
        priceFeed = AggregatorV3Interface(0xB97Ad0E74fa7d920791E90258A6E2085088b4320);
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice() external view returns (int) {
        (
        ,
        int price,
        ,
        ,

        ) = priceFeed.latestRoundData();
        return price;
    }

    function getDecimals() external view returns (uint8) {
        return priceFeed.decimals();
    }
}