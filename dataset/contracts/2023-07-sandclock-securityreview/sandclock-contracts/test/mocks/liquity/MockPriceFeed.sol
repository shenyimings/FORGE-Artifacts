// SPDX-License-Identifier: MIT
pragma solidity >0.8.10;

import {IPriceFeed} from "../../../src/interfaces/chainlink/IPriceFeed.sol";

contract MockPriceFeed is IPriceFeed {
    string public constant NAME = "PriceFeed";

    int256 public lastGoodPrice;

    function latestAnswer() external view override returns (int256) {
        return lastGoodPrice;
    }

    function setPrice(uint256 price) external {
        lastGoodPrice = int256(price);
    }
}
