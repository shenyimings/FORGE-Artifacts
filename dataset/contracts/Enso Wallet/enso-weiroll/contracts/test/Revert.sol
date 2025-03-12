// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.16;

contract Revert {

    error LogUint(uint256 a);
    error Log2Uints(uint256 a, uint256 b);
    error Log3Uints(uint256 a, uint256 b, uint256 c);

    function fail() public pure {
        require(false, "Hello World!");
    }

    function fail32ByteMessage() public pure {
        require(false, "Hello World!!!!!!!!!!!!!!!!!!!!!");
    }

    function assertFail() public pure returns (bool) {
        assert(false);
        return true;
    }

    function uintError1() public pure {
        revert LogUint(1);
    }

    function uintError2() public pure {
        revert Log2Uints(1, 2);
    }

    function uintError3() public pure {
        revert Log3Uints(1, 2, 3);
    }

    // @dev This error duplicates the emitting of "Hello World!" error message using 3 uints
    function fakeErrorMessage() public pure {
        revert Log3Uints(32, 12, uint256(0x48656c6c6f20576f726c64210000000000000000000000000000000000000000));
    }

    //@dev The error uses the incorrect length when encoding "Hello World!"
    function poorlyEncodedFakeErrorMessage() public pure {
        revert Log3Uints(32, 13, uint256(0x48656c6c6f20576f726c64210000000000000000000000000000000000000000));
    }
}