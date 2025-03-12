// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

contract Fixed {
    struct Struct {
      uint256 a;
      uint256 b;
    }

    function addStruct(Struct memory values)
        external
        pure
        returns (uint256)
    {
        return values.a + values.b;
    }

    function addArray(uint256[2] calldata values)
        external
        pure
        returns (uint256)
    {
        return values[0] + values[1];
    }
}
