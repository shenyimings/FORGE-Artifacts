// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

library SafeDecimalMath {
    uint8 private constant DECIMALS = 18;
    uint private constant UNIT = 10 ** DECIMALS;

    function multiplyDecimal(uint x, uint y) internal pure returns (uint) {
        return (x * y) / UNIT;
    }

    function divideDecimal(uint x, uint y) internal pure returns (uint) {
        return (x * UNIT) / y;
    }

    function min(uint x, uint y) internal pure returns (uint) {
        return x < y ? x : y;
    }

    function max(uint x, uint y) internal pure returns (uint) {
        return x < y ? y : x;
    }
}
