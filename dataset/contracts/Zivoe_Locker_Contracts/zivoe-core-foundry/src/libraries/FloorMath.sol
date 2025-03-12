// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

/// @notice Specialized math functions that always return uint256 and never revert. 
///         This condenses and simplifies the codebase, for example trySub() from OpenZeppelin 
///         would have sufficed, however they returned tuples to include information 
///         about the success of the function, which is inefficient for our purposes. 
library FloorMath {
    
    /// @notice Returns 0 if divisions results in value less than 1, or division by zero.
    function floorDiv(uint256 x, uint256 y) internal pure returns (uint256) {
        unchecked {
            if (y == 0) return 0;
            if (y > x) return 0;
            return (x / y);
        }
    }

    /// @notice The return value is if subtraction results in underflow.
    ///         Subtraction routine that does not revert and returns a singleton, 
    ///         making it cheaper and more suitable for composition and use as an attribute.
    ///         It was made to be a cheaper version of openZepelins trySub.
    function floorSub(uint256 x, uint256 y) internal pure returns (uint256) {
        unchecked {
            if (y > x) return 0;
            return (x - y);
        }
    }
    
    /// @notice Returns the smallest of two numbers.
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}