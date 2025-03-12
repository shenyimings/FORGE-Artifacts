// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IOracle } from  "../../src/interfaces/IOracle.sol";

contract FakeOracle is IOracle {
    uint256 _price = 0;

    function price(uint80) external view returns (uint256) {
        return _price;
    }

    function setPrice(uint256 price_) external {
        _price = price_;
    }

    function timestamp(uint80) external view returns (uint256) {
        return block.timestamp;
    }

    function roundId() external pure returns (uint80) {
        return 1;
    }
}
