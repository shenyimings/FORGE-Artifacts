// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.16;

contract Math {
    function add(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) public pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) public pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) public pure returns (uint256) {
        return a / b;
    }

    function sum(uint256[] memory values)
        public
        pure
        returns (uint256 ret)
    {
        uint256 valuesLength = values.length;
        for (uint256 i; i < valuesLength; ++i) {
            ret += values[i];
        }
    }
}
