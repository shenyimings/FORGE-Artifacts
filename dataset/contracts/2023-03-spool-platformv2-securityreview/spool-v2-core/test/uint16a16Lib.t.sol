// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/libraries/uint16a16Lib.sol";
import "./libraries/Arrays.sol";

contract LibHelper {
    function set(uint16a16 a, uint256 i, uint256 value) external pure returns (uint16a16) {
        uint16a16 res = uint16a16Lib.set(a, i, value);
        return res;
    }

    function set(uint16a16 a, uint256[] memory values) external pure returns (uint16a16) {
        uint16a16 res = uint16a16Lib.set(a, values);
        return res;
    }

    function get(uint16a16 a, uint256 i) external pure returns (uint256) {
        uint256 res = uint16a16Lib.get(a, i);
        return res;
    }
}

contract uint16a16LibTest is Test {
    using uint16a16Lib for uint16a16;

    function test_get_revertOnIndexOutOfBounds() public {
        uint16a16 val;
        LibHelper helper = new LibHelper();
        vm.expectRevert();
        helper.get(val, 100);
    }

    function test_setValueSingle() public {
        uint16a16 val;

        LibHelper helper = new LibHelper();
        val = helper.set(val, 0, 10);
        val = helper.set(val, 1, 20);
        val = helper.set(val, 2, 30);

        assertEq(helper.get(val, 0), 10);
        assertEq(helper.get(val, 1), 20);
        assertEq(helper.get(val, 2), 30);
    }

    function test_setValueArray() public {
        uint16a16 val;

        LibHelper helper = new LibHelper();
        val = helper.set(val, Arrays.toArray(10, 20, 30));

        assertEq(helper.get(val, 0), 10);
        assertEq(helper.get(val, 1), 20);
        assertEq(helper.get(val, 2), 30);
    }
}
