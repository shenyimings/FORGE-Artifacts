// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

library Bitwise {
    function get8BitUintByIndex(uint256 bitwiseData, uint256 i) internal pure returns(uint256) {
        return (bitwiseData >> (8 * i)) & type(uint8).max;
    }

    // 14 bits is used for strategy proportions in a vault as FULL_PERCENT is 10_000
    function get14BitUintByIndex(uint256 bitwiseData, uint256 i) internal pure returns(uint256) {
        return (bitwiseData >> (14 * i)) & (16_383); // 16.383 is 2^14 - 1
    }

    function set14BitUintByIndex(uint256 bitwiseData, uint256 i, uint256 num14bit) internal pure returns(uint256) {
        return bitwiseData + (num14bit << (14 * i));
    }

    function reset14BitUintByIndex(uint256 bitwiseData, uint256 i) internal pure returns(uint256) {
        return bitwiseData & (~(16_383 << (14 * i)));
    }

    function get16BitUintByIndex(uint256 bitwiseData, uint256 i) internal pure returns(uint256) {
        return (bitwiseData >> (16 * i)) & type(uint16).max;
    }

    function set16BitUintByIndex(uint256 bitwiseData, uint256 i, uint256 num16bit) internal pure returns(uint256) {
        return bitwiseData + (num16bit << (16 * i));
    }

    function get24BitUintByIndexCast(uint256 bitwiseData, uint256 i) internal pure returns(uint24) {
        return uint24((bitwiseData >> (24 * i)) & type(uint24).max);
    }

    function set24BitUintByIndex(uint256 bitwiseData, uint256 i, uint256 num24bit) internal pure returns(uint256) {
        return bitwiseData + (num24bit << (24 * i));
    }
}
