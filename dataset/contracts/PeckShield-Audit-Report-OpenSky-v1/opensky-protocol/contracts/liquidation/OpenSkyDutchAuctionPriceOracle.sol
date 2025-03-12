// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';

import '../interfaces/IOpenSkyDutchAuctionPriceOracle.sol';

contract OpenSkyDutchAuctionPriceOracle is IOpenSkyDutchAuctionPriceOracle {
    using SafeMath for uint256;

    uint256 constant DURATION_ONE = 2 days;
    uint256 constant DURATION_TWO = 3 days;
    uint256 constant SPACING = 5 minutes; // price descend every 5 minutes

    function calculatePrice(
        uint256 startPrice,
        uint256 endPrice,
        uint256 startTime,
        uint256 endTime,
        uint256 priceTime
    ) public view returns (uint256) {
        uint256 spacingAmount = (endTime - startTime) / SPACING;
        uint256 priceUint = (startPrice - endPrice) / spacingAmount;
        uint256 currentIndex = (priceTime - startTime) / SPACING;
        uint256 price = startPrice - currentIndex * priceUint;
        return price;
    }

    function getPrice(uint256 reservePrice, uint256 startTime) external view override returns (uint256) {
        // 10*loan => 3*loan=> 1.2*loan
        uint256 startPrice = reservePrice * 10;
        uint256 turningPrice = reservePrice * 3;
        uint256 endPrice = (reservePrice * 12000) / 10000;
        uint256 turnTime = startTime + DURATION_ONE;
        uint256 endTime = turnTime + DURATION_TWO;

        uint256 price = endPrice;

        if (block.timestamp <= startTime) {
            price = startPrice;
        } else if (block.timestamp <= turnTime) {
            // price = startPrice - ((block.timestamp - startTime) * (startPrice - turningPrice)) / DURATION_ONE;
            // price = startPrice.sub((block.timestamp - startTime).mul(startPrice.sub(turningPrice)).div(DURATION_ONE));
            price = calculatePrice(startPrice, turningPrice, startTime, turnTime, block.timestamp);
        } else if (block.timestamp < endTime) {
            // price = turningPrice - ((block.timestamp - turnTime) * (turningPrice - endPrice)) / DURATION_TWO;
            // price = turningPrice.sub((block.timestamp.sub(turnTime)).mul(turningPrice.sub(endPrice)).div(DURATION_TWO));
            price = calculatePrice(turningPrice, endPrice, turnTime, endTime, block.timestamp);
        } else {
            price = endPrice;
        }
        return price;
    }
}
