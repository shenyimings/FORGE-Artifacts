// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../../../oracle/AggregatorV3Interface.sol";

contract ChainlinkBNBUSDPriceConsumer {

    AggregatorV3Interface internal priceFeed;


    constructor () public {
        priceFeed = AggregatorV3Interface(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE);
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