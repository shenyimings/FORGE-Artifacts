// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

library Cast {
    /// @dev casts an uint256 to an uint32 bounded by uint32 range of values
    /// @dev to avoid reverts and overflows
    function toUint32Bounded(uint256 value) internal pure returns (uint32) {
        uint32 value32 = (value <= type(uint32).max) ? uint32(value) : type(uint32).max;
        return value32;
    }

    /// @dev casts an int256 to an int192 bounded by int192 range of values
    /// @dev to avoid reverts and overflows
    function toInt192Bounded(int256 value) internal pure returns (int192) {
        int192 value192 = (type(int192).min <= value && value <= type(int192).max)
            ? int192(value)
            : (value < type(int192).min ? type(int192).min : type(int192).max);
        return value192;
    }
}
