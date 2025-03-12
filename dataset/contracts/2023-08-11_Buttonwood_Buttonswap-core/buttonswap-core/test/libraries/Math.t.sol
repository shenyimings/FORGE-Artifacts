// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "buttonswap-core_forge-std/Test.sol";
import {Math} from "../../src/libraries/Math.sol";

contract MathTest is Test {
    function test_min(uint256 value1, uint256 value2) public {
        uint256 min = Math.min(value1, value2);
        assertLe(min, value1);
        assertLe(min, value2);
    }

    function test_sqrt(uint256 root) public {
        vm.assume(root < 2 ** 128);
        assertEq(Math.sqrt(root * root), root);
    }

    function test_sqrt_SpecificValues() public {
        assertEq(Math.sqrt(0), 0);
        assertEq(Math.sqrt(1), 1);
        assertEq(Math.sqrt(2), 1);
        assertEq(Math.sqrt(3), 1);
        assertEq(Math.sqrt(4), 2);
    }
}
