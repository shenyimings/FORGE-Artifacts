//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../src/libraries/LibBytes.sol";

contract BytesInputs {
    function slice(bytes memory _bytes, uint256 _start, uint256 _length) public pure returns (bytes memory) {
        return LibBytes.slice(_bytes, _start, _length);
    }
}

contract BytesTest is Test {
    BytesInputs internal bytesInputs;

    function setUp() external {
        bytesInputs = new BytesInputs();
    }

    function testSliceOverflow() public {
        vm.expectRevert(abi.encodeWithSignature("SliceOverflow()"));
        bytesInputs.slice("bytes !", 0, type(uint256).max);
    }

    function testSliceOutOfBounds() public {
        vm.expectRevert(abi.encodeWithSignature("SliceOutOfBounds()"));
        bytesInputs.slice("bytes !", 5, 5);
    }

    function testSlice() public {
        assertEq(bytesInputs.slice("bytes !", 0, 4), "byte");
    }
}
