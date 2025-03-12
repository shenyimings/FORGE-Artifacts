// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

library SignedSafeDecimalMath {
    uint8 private constant DECIMALS = 18;
    int private constant UNIT = int(10 ** DECIMALS);

    function multiplyDecimal(int x, int y) internal pure returns (int) {
        return (x * y) / UNIT;
    }

    function divideDecimal(int x, int y) internal pure returns (int) {
        return (x * UNIT) / y;
    }

    function sign(int x) internal pure returns (int) {
        if (x > 0) return UNIT;
        if (x < 0) return -UNIT;
        return 0;
    }

    function abs(int x) internal pure returns (int) {
        return x < 0 ? -x : x;
    }

    function min(int x, int y) internal pure returns (int) {
        return x < y ? x : y;
    }

    function max(int x, int y) internal pure returns (int) {
        return x < y ? y : x;
    }
}
