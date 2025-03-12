pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        require(c >= a, "c >= a");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require(b <= a, "b <= a");
        c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a * b;
        require(a == 0 || c / a == b, "a == 0 || c / a == b");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require(b > 0, "b > 0");
        c = a / b;
        return c;
    }
}
