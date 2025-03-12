// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../libraries/Cast.sol";

contract CastMock {
    using Cast for uint256;
    using Cast for int256;

    function toUint32Bounded(uint256 value) external pure returns (uint32) {
        return value.toUint32Bounded();
    }

    function toInt192Bounded(int256 value) external pure returns (int192) {
        return value.toInt192Bounded();
    }
}
