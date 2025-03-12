// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import {DSTest} from "ds-test/test.sol";

import {VM} from "../utils/VM.sol";
import {console} from "../utils/console.sol";

contract BaseTest is DSTest {
    uint256 internal constant ROUNDING_ERROR_THRESHOLD = 1000;
    VM internal constant vm = VM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function assertEqEpsilonBelow(
        uint256 a,
        uint256 b,
        uint256 epsilonInv
    ) internal {
        if (absDifference(a, b) <= ROUNDING_ERROR_THRESHOLD) {
            // rounding error
            return;
        }
        if (b / epsilonInv == 0 && b != 0) {
            epsilonInv = b;
        }

        assertLe(a, b + 1);
        assertGe(a, b - b / epsilonInv);
    }

    function assertEqEpsilonAround(
        uint256 a,
        uint256 b,
        uint256 epsilonInv
    ) internal {
        if (absDifference(a, b) <= ROUNDING_ERROR_THRESHOLD) {
            // rounding error
            return;
        }
        if (b / epsilonInv == 0 && b != 0) {
            epsilonInv = b;
        }

        assertLe(a, b + b / epsilonInv + 1);
        assertGe(a, b - b / epsilonInv);
    }

    function assertEqDecimalEpsilonBelow(
        uint256 a,
        uint256 b,
        uint256 decimals,
        uint256 epsilonInv
    ) internal {
        if (absDifference(a, b) <= ROUNDING_ERROR_THRESHOLD) {
            // rounding error
            return;
        }
        if (b / epsilonInv == 0 && b != 0) {
            epsilonInv = b;
        }

        assertLeDecimal(a, b + 1, decimals);
        assertGeDecimal(a, b - b / epsilonInv, decimals);
    }

    function assertEqDecimalEpsilonAround(
        uint256 a,
        uint256 b,
        uint256 decimals,
        uint256 epsilonInv
    ) internal {
        if (absDifference(a, b) <= ROUNDING_ERROR_THRESHOLD) {
            // rounding error
            return;
        }
        if (b / epsilonInv == 0 && b != 0) {
            epsilonInv = b;
        }

        assertLeDecimal(a, b + b / epsilonInv + 1, decimals);
        assertGeDecimal(a, b - b / epsilonInv, decimals);
    }

    function absDifference(uint256 a, uint256 b)
        internal
        pure
        returns (uint256)
    {
        if (a >= b) {
            return a - b;
        } else {
            return b - a;
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
