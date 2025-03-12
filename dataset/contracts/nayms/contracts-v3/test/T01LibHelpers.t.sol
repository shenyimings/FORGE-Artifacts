// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { D03ProtocolDefaults, console2, LibHelpers } from "./defaults/D03ProtocolDefaults.sol";

contract T01LibHelpers is D03ProtocolDefaults {
    function testGetIdForObjectAtIndexFuzz(uint256 i) public {
        assertEq(LibHelpers._getIdForObjectAtIndex(i), keccak256(abi.encodePacked(i)));
    }

    function testGetIdForAddressFuzz(address a) public {
        assertEq(LibHelpers._getIdForAddress(a), bytes32(bytes20(a)));
    }

    function testGetSenderId() public {
        assertEq(LibHelpers._getSenderId(), LibHelpers._getIdForAddress(msg.sender));
    }

    function testGetAddressFromIdFuzz(bytes32 id) public {
        assertEq(LibHelpers._getAddressFromId(id), address(bytes20(id)));
    }

    function testAddressToBytes32Fuzz(address a) public {
        assertEq(LibHelpers._addressToBytes32(a), LibHelpers._bytesToBytes32(abi.encode(a)));
    }

    function testStringToBytes32Fuzz(string memory s) public {
        assertEq(LibHelpers._stringToBytes32(s), LibHelpers._bytesToBytes32(bytes(s)));
    }

    function testBytes32ToStringFuzz(bytes32 b32) public {
        assertEq(LibHelpers._bytes32ToString(b32), string(LibHelpers._bytes32ToBytes(b32)));
    }

    function testBytesToBytes32Fuzz(bytes memory b) public {
        if (b.length == 0) {
            assertEq(LibHelpers._bytesToBytes32(b), 0x0);
        } else {
            bytes32 result;
            assembly {
                result := mload(add(b, 32))
            }
            assertEq(LibHelpers._bytesToBytes32(b), result);
        }
    }

    function testBytes32ToBytesFuzz(bytes32 b32) public {
        bytes memory b = new bytes(32);
        assembly {
            mstore(add(b, 32), b32)
        }
        assertEq(LibHelpers._bytes32ToBytes(b32), b);
    }
}
