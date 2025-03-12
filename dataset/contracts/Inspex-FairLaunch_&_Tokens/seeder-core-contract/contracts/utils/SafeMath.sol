// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256 result) {
        result = a + b;
        require(result >= a, "overflow is prevented");
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256 result) {
        require(a >= b, "overflow is prevented");
        result = a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256 result) {
        result = a * b;

        if (b > 0) {
            require((result / b) == a, "overflow is prevented");
        }
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256 result) {
        require(b > 0, "divide by zero error");
        result = a / b;
    }

    // Sample data: precision = 1E6
    function div(uint256 a, uint256 b, uint256 precision) internal pure returns (uint256 result, uint256 returnPrecision) {
        require(b > 0, "divide by zero error");
        returnPrecision = precision;
        result = (a * precision) / b;

        require(a <= (a * precision), "overflow is prevented");
        require((result * b) <= (a * precision), "overflow is prevented");
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256 result) {
        require(b > 0, "divide by zero error");
        result = a % b;
    }
}
