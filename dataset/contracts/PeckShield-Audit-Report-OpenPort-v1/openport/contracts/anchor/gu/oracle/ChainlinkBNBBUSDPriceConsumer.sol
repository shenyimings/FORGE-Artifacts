// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../../../oracle/AggregatorV3Interface.sol";

contract ChainlinkBNBBUSDPriceConsumer {

    AggregatorV3Interface internal priceBNBUSDFeed;
    AggregatorV3Interface internal priceBUSDUSDFeed;
    int256 public PRICE_PRECISION = 1e8;

    constructor () public {
        priceBNBUSDFeed = AggregatorV3Interface(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE);
        priceBUSDUSDFeed = AggregatorV3Interface(0xcBb98864Ef56E9042e7d2efef76141f15731B82f);
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice() external view returns (int) {
        (
            , 
            int bnbUSDPrice,
            ,
            ,
        ) = priceBNBUSDFeed.latestRoundData();

        (
            ,
            int busdUSDPrice,
            ,
            ,
        ) = priceBUSDUSDFeed.latestRoundData();

        int price = bnbUSDPrice * PRICE_PRECISION / busdUSDPrice;
        require(price > 0, "error chainlink price");

        return price;
    }

    function getDecimals() external view returns (uint8) {
        return priceBNBUSDFeed.decimals();
    }
}