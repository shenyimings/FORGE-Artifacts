pragma solidity ^0.5.16;

contract FakePriceOracle {
    mapping(address=>uint) price;

    function setPrice(address cToken, uint newPrice) external {
        price[cToken] = newPrice;
    }

    function getUnderlyingPrice(address cToken) external view returns (uint) {
        return price[cToken];
    }
}
