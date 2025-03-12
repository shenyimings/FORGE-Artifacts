// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

// uint128 addition and subtraction, with overflow protection.

library ERDSafeMath128 {
    function add(uint128 a, uint128 b) internal pure returns (uint128) {
        uint128 c = a + b;
        require(c >= a, "ERDSafeMath128: addition overflow");

        return c;
    }

    function sub(uint128 a, uint128 b) internal pure returns (uint128) {
        require(b <= a, "ERDSafeMath128: subtraction overflow");
        uint128 c = a - b;

        return c;
    }
}
