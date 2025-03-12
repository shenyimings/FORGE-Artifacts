// contracts/Project.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IOracle.sol";

contract MockOracle is IOracle, Ownable {
    uint256 private price_;

    constructor(uint256 price) {
        price_ = price;
    }

    function getPrice() external override view returns(uint256) {
        return price_;
    }

    function setPrice(uint256 price) external onlyOwner {
        require(price != 0, "MockOracle: invalid price");
        price_ = price;
    }
}

