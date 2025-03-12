// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../../../oracle/AggregatorV3Interface.sol";

contract ChainlinkBUSDUSDPriceConsumer {

    AggregatorV3Interface internal priceFeed;


    constructor () public {
        priceFeed = AggregatorV3Interface(0xcBb98864Ef56E9042e7d2efef76141f15731B82f);
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