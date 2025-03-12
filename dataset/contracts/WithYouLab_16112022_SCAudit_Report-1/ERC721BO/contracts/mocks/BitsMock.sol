// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Bits.sol";

contract BitsMock {
    using Bits for uint256;

    function popCount(uint256 i) public pure returns (uint256) {
        return i.popCount();
    }

    function indexOf(uint256 i, uint256 n) public pure returns (uint256) {
        return i.indexOf(n);
    }
}
