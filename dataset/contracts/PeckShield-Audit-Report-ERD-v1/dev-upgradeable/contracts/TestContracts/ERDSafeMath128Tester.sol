// SPDX-License-Identifier: IMT
pragma solidity 0.8.18;

import "../Dependencies/ERDSafeMath128.sol";

/* Tester contract for math functions in ERDSafeMath128.sol library. */

contract ERDSafeMath128Tester {
    using ERDSafeMath128 for uint128;

    function add(uint128 a, uint128 b) external pure returns (uint128) {
        return a.add(b);
    }

    function sub(uint128 a, uint128 b) external pure returns (uint128) {
        return a.sub(b);
    }
}
