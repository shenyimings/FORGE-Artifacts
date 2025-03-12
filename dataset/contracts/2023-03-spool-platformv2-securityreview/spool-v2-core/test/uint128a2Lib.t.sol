// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/libraries/uint128a2Lib.sol";
import "./libraries/Arrays.sol";

contract LibHelper {
    function set(uint128a2 a, uint256 i, uint256 value) external pure returns (uint128a2) {
        uint128a2 res = uint128a2Lib.set(a, i, value);
        return res;
    }

    function get(uint128a2 a, uint256 i) external pure returns (uint256) {
        uint256 res = uint128a2Lib.get(a, i);
        return res;
    }
}

contract uint128a2LibTest is Test {
    using uint128a2Lib for uint128a2;

    function test_get_revertOnIndexOutOfBounds() public {
        uint128a2 val;
        LibHelper helper = new LibHelper();
        vm.expectRevert();
        helper.get(val, 3);
    }

    function test_setValueSingle() public {
        uint128a2 val;

        LibHelper helper = new LibHelper();
        val = helper.set(val, 0, 10);
        val = helper.set(val, 1, 20);

        assertEq(helper.get(val, 0), 10);
        assertEq(helper.get(val, 1), 20);
    }
}
