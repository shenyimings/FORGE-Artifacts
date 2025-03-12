// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.11;

import "../Libraries/Math.sol";

contract Arrays is Math {
    function sumAndMultiply(uint256[] calldata a, uint256[] calldata b)
        external
        pure
        returns (uint256 ret)
    {
        uint256 sumA;
        for (uint256 i = 0; i < a.length; i++) {
            sumA += a[i];
        }
        uint256 sumB;
        for (uint256 i = 0; i < b.length; i++) {
            sumB += b[i];
        }
        ret = sumA * sumB;
    }

    function concatArray(string[] memory strings)
        external
        pure
        returns (string memory ret)
    {
        if (strings.length > 0) {
            ret = string(abi.encodePacked(strings[0]));
            for (uint256 i = 1; i < strings.length; i++) {
              ret = string(abi.encodePacked(ret, strings[i]));
            }
        }
    }

    function sumArrays(uint256[][] calldata values)
        external
        pure
        returns (uint256 ret)
    {
        uint256[] memory sums = new uint256[](values.length);
        for (uint256 i; i < values.length; i++) {
            sums[i] =  sum(values[i]);
        }
        ret = sum(sums);
    }

    function returnStringArrayLength(string[] memory values)
        external
        pure
        returns (uint256)
    {
        return values.length;
    }
}
