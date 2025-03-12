// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import "buttonswap-core_forge-std/Test.sol";
import {PriceAssertion} from "./PriceAssertion.sol";

contract PriceAssertionTest is Test {
    function test_isTermWithinTolerance(uint112 fixedB, uint112 targetA, uint112 targetB) public {
        vm.assume(fixedB > 0);
        vm.assume(targetA > 0);
        vm.assume(targetB > 0);
        vm.assume(fixedB < type(uint112).max / targetA);
        uint112 variableA = (targetA * fixedB) / targetB;
        vm.assume(variableA > 0);
        uint112 limitA = type(uint112).max;
        uint112 tolerance = 1;
        bool withinTolerance =
            PriceAssertion.isTermWithinTolerance(variableA, limitA, fixedB, targetA, targetB, tolerance);
        assertEq(withinTolerance, true, "New price outside of tolerance");
    }
}
