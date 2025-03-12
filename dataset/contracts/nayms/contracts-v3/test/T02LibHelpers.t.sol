// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { D03ProtocolDefaults, LibHelpers } from "./defaults/D03ProtocolDefaults.sol";

contract T02LibHelpers is D03ProtocolDefaults {
    function setUp() public virtual override {
        super.setUp();
    }

    function testIdForObjectAtIndexFuzz(uint256 idx) public {
        assertEq(LibHelpers._getIdForObjectAtIndex(idx), keccak256(abi.encodePacked(idx)));
    }

    function testGetIdForAddressFuzz(address a) public {
        assertEq(LibHelpers._getIdForAddress(a), bytes32(bytes20(a)));
    }

    function testGetAddressFromIdFuzz(bytes32 b32) public {
        assertEq(LibHelpers._getAddressFromId(b32), address(bytes20(b32)));
    }

    function testAddressToBytes32Fuzz(address a) public {
        assertEq(LibHelpers._addressToBytes32(a), LibHelpers._bytesToBytes32(abi.encode(a)));
    }

    function testStringToBytes32Fuzz(string memory s) public {
        assertEq(LibHelpers._stringToBytes32(s), LibHelpers._bytesToBytes32(bytes(s)));
    }

    function testBytes32ToStringFuzz(bytes32 b32) public {
        bytes memory ret = bytes(LibHelpers._bytes32ToString(b32));
        bytes memory exp = bytes(LibHelpers._bytes32ToBytes(b32));
        assertEq(ret, exp);
    }

    function testBytesToBytes32(bytes memory b) public {
        bytes32 result;
        if (b.length == 0) {
            result = 0x0;
        }
        assembly {
            result := mload(add(b, 32))
        }
        assertEq(LibHelpers._bytesToBytes32(b), result);
    }

    function testBytes32ToBytes(bytes32 b32) public {
        bytes memory b = new bytes(32);
        assembly {
            mstore(add(b, 32), b32)
        }
        assertEq(LibHelpers._bytes32ToBytes(b32), b);
    }

    function TODO_testGetSenderId() public {
        // references msg.sender internally so we we need a fixture to test it
    }
}
