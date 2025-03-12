// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

library NumberUtils {
    function addCheckOverflow(uint256 a, uint256 b) internal pure returns (bool) {
        uint256 c = 0;
        unchecked {
            c = a + b;
        }
        return c < a || c < b;
    }

    function mulCheckOverflow(uint256 a, uint256 b) internal pure returns (bool) {
        if (a == 0 || b == 0) {
            return false;
        }
        uint256 c;
        unchecked {
            c = a * b;
        }
        return c / a != b;
    }

    function mulDivCheckOverflow(uint256 a, uint256 b, uint256 denominator) internal pure returns (bool) {
        // Taken from prb - math
        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly ("memory-safe") {
            let mm := mulmod(a, b, not(0))
            prod0 := mul(a, b)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }
        return prod1 >= denominator;
    }
}
