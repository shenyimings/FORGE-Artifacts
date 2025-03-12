// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

contract ChainlinkOracle {

    function getPrice(address feed) external view returns (uint256)  {
        require(feed != address(0), '!feed-error');

        (,int price,,uint timeStamp,) = AggregatorV3Interface(feed).latestRoundData();

        require(price > 0, '!price');
        require(timeStamp > 0, '!timeStamp');

        uint8 decimals = AggregatorV3Interface(feed).decimals();

        uint256 priceToReturn;
        if (decimals != 8) {
            priceToReturn = uint256(price) * (10**8) / (10**uint256(decimals));
        } else {
            priceToReturn = uint256(price);
        }
        return priceToReturn;
    }
}
