// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Array} from "../libs/Array.sol";

contract ArrayTest {
    function sorted(uint256[] memory array) public pure returns (bool) {
        return Array.sorted(array);
    }

    function unique(uint256[] memory array) public pure returns (bool) {
        return Array.unique(array);
    }
}
