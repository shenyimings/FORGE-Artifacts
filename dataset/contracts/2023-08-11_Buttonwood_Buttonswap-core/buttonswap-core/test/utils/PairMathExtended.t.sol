// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import "buttonswap-core_forge-std/Test.sol";
import {PairMathExtended} from "./PairMathExtended.sol";

contract PairMathExtendedTest is Test {
    function test_getSwapOutputAmount(uint256 inputAmount, uint256 poolInput, uint256 poolOutput) public {
        // Pools will be capped by uint112
        vm.assume(poolInput < type(uint112).max);
        vm.assume(poolOutput < type(uint112).max);

        // Ensuring we don't divide by zero
        vm.assume(poolInput > 0 || inputAmount > 0);

        // Ensuring we don't overflow
        vm.assume(inputAmount == 0 || inputAmount < type(uint256).max / 997);
        vm.assume(inputAmount == 0 || poolOutput == 0 || inputAmount < type(uint256).max / (poolOutput * 997));

        uint256 outputAmount = PairMathExtended.getSwapOutputAmount(inputAmount, poolInput, poolOutput);
        uint256 expectedOutputAmount = (poolOutput * inputAmount * 997) / ((poolInput * 1000) + (inputAmount * 997));

        assertEq(outputAmount, expectedOutputAmount, "outputAmount does not match expectedOutputAmount");
    }
}
