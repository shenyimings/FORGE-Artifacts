// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Power} from "../libs/Power.sol";

contract PowerTest {
    function raise(uint256 n, uint256 exp) external pure returns (uint256) {
        return Power.raise(n, exp);
    }
}
