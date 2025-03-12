// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Oracle} from "../../src/core/Oracle.sol";

contract OracleForTest is Oracle {
    function setPrice(string memory symbol, uint256 ts, uint256 _price) public {
        price[symbol] = _price;
        historyPrice[symbol][ts] = _price;
    }
}