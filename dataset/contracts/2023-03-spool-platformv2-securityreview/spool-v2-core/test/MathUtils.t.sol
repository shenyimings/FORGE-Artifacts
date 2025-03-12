// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/libraries/MathUtils.sol";

contract MathUtilsTest is Test {
    function test_getMinValue() public {
        assertEq(MathUtils.min(10, 20), 10);
    }

    function test_getProportion128() public {
        assertEq(MathUtils.getProportion128(10, 20, 5), 40);
    }

    function test_getProportion128Unchecked() public {
        assertEq(MathUtils.getProportion128Unchecked(10, 20, 5), 40);
    }
}
