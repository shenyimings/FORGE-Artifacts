// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "./Interfaces/IOracle.sol";
import "./Dependencies/Ownable.sol";

contract GMUOracle is Ownable, IOracle {
    uint256 public price = 1e6;
    string constant public NAME = "GMU/USD Oracle";

    event PriceChange(uint256 timestamp, uint256 price);

    constructor(uint256 startingPrice) public {
        price = startingPrice;
    }

    function getPrice() public view override returns (uint256) {
        return price;
    }

    function getDecimalPrecision() public view override returns (uint256) {
        return 6;
    }

    function setPrice(uint256 _price) public onlyOwner {
        require(_price >= 0, "Oracle: price cannot be < 0");
        price = _price;
        emit PriceChange(block.timestamp, _price);
    }
}