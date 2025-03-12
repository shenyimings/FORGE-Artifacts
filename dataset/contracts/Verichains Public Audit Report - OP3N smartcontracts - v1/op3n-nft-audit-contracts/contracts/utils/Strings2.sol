//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

library Strings2 {
    function toString(address x) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(x)));
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < 20; i++) {
            str[2+i*2] = alphabet[uint(uint8(value[i + 12] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(value[i + 12] & 0x0f))];
        }
        return string(str);
    }
}
