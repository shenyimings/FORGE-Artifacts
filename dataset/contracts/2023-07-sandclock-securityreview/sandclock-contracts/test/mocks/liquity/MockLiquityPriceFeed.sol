// SPDX-License-Identifier: MIT
pragma solidity >0.8.10;

interface IPriceFeed {
    event LastGoodPriceUpdated(uint256 _lastGoodPrice);

    function fetchPrice() external returns (uint256);
}

contract MockLiquityPriceFeed is IPriceFeed {
    string public constant NAME = "PriceFeed";

    uint256 public lastGoodPrice;

    function fetchPrice() external view override returns (uint256) {
        return lastGoodPrice;
    }

    function setPrice(uint256 price) external {
        lastGoodPrice = price;

        emit LastGoodPriceUpdated(lastGoodPrice);
    }
}
