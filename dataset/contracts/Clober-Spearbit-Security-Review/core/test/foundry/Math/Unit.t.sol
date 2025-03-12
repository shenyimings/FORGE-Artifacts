// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../../contracts/utils/Math.sol";

contract MathLibraryUnitTest is Test {
    function divide(
        uint256 a,
        uint256 b,
        bool roundingUp
    ) internal pure returns (uint256 ret) {
        ret = a / b;
        if (roundingUp && a % b > 0) {
            ++ret;
        }
    }

    function testDivide(
        uint256 a,
        uint256 b,
        bool roundingUp
    ) public {
        vm.assume(0 < b);

        assertEq(Math.divide(a, b, roundingUp), divide(a, b, roundingUp), "DIVIDE_WITH_ROUNDING");
    }

    function testDivide_Zero() external {
        assertEq(Math.divide(0, 17, false), 0);
        assertEq(Math.divide(0, 23, true), 0);
        assertEq(Math.divide(2, 17, false), 0);
        assertEq(Math.divide(117, 118, false), 0);
        assertEq(Math.divide(1, type(uint256).max, false), 0);
        assertEq(Math.divide(type(uint256).max - 1, type(uint256).max, false), 0);
    }

    function testDivide_One() external {
        assertEq(Math.divide(2, 17, true), 1);
        assertEq(Math.divide(117, 118, true), 1);
        assertEq(Math.divide(21, 171, true), 1);
        assertEq(Math.divide(34, 9876, true), 1);
        assertEq(Math.divide(2, 3, true), 1);
        assertEq(Math.divide(74, 100238, true), 1);
        assertEq(Math.divide(1, 2, true), 1);
        assertEq(Math.divide(234, 8656, true), 1);
        assertEq(Math.divide(type(uint256).max - 1, type(uint256).max, true), 1);
        assertEq(Math.divide(1, type(uint256).max, true), 1);
    }

    function testDivide_Divide_By_One() external {
        assertEq(Math.divide(2, 1, true), 2);
        assertEq(Math.divide(117, 1, false), 117);
        assertEq(Math.divide(21, 1, true), 21);
        assertEq(Math.divide(34, 1, false), 34);
        assertEq(Math.divide(2, 1, true), 2);
        assertEq(Math.divide(74, 1, false), 74);
        assertEq(Math.divide(1, 1, true), 1);
        assertEq(Math.divide(234, 1, true), 234);
        assertEq(Math.divide(type(uint256).max - 1, 1, true), type(uint256).max - 1);
        assertEq(Math.divide(type(uint256).max, 1, true), type(uint256).max);
        assertEq(Math.divide(type(uint256).max - 1, 1, false), type(uint256).max - 1);
        assertEq(Math.divide(type(uint256).max, 1, false), type(uint256).max);
    }

    function testDivide_Divide_Max() external {
        assertEq(Math.divide(type(uint256).max, 765456, true), divide(type(uint256).max, 765456, true));
        assertEq(Math.divide(type(uint256).max, 567654, true), divide(type(uint256).max, 567654, true));
        assertEq(Math.divide(type(uint256).max, 1, true), divide(type(uint256).max, 1, true));
        assertEq(Math.divide(type(uint256).max, 12, true), divide(type(uint256).max, 12, true));
        assertEq(Math.divide(type(uint256).max, 8765434567876, true), divide(type(uint256).max, 8765434567876, true));
        assertEq(Math.divide(type(uint256).max, 654, false), divide(type(uint256).max, 654, false));
        assertEq(Math.divide(type(uint256).max, 2, false), divide(type(uint256).max, 2, false));
        assertEq(Math.divide(type(uint256).max, 4567, false), divide(type(uint256).max, 4567, false));
        assertEq(Math.divide(type(uint256).max, 65456, false), divide(type(uint256).max, 65456, false));
    }
}
