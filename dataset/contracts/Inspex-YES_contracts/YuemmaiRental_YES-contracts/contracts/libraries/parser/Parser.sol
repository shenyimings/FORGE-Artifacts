//SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0;

library Parser {
    function toUint256(bytes memory _bytes)
        internal
        pure
        returns (uint256 value)
    {
        assembly {
            value := mload(add(_bytes, 0x20))
        }
    }
}
