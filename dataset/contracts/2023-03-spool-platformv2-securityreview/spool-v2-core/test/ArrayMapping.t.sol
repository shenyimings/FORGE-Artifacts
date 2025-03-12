// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/libraries/MathUtils.sol";
import "./libraries/Arrays.sol";

contract LibHelper {
    function min(uint256 a, uint256 b) external pure returns (uint256) {
        uint256 result = MathUtils.min(a, b);
        return result;
    }

    function getProportion128(uint256 mul1, uint256 mul2, uint256 div) external pure returns (uint128) {
        uint128 result = MathUtils.getProportion128(mul1, mul2, div);
        return result;
    }

    function getProportion128Unchecked(uint256 mul1, uint256 mul2, uint256 div) external pure returns (uint128) {
        uint128 result = MathUtils.getProportion128Unchecked(mul1, mul2, div);
        return result;
    }
}

contract MathUtilsTest is Test {
    using MathUtils for uint256;

    function test_getMinValue() public {
        assertEq(new LibHelper().min(10, 20), 10);
    }

    function test_getProportion128() public {
        assertEq(new LibHelper().getProportion128(10, 20, 5), 40);
    }

    function test_getProportion128Unchecked() public {
        assertEq(new LibHelper().getProportion128Unchecked(10, 20, 5), 40);
    }
}
