// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./../libraries/Math.sol";

contract TestMath {
    using Math for uint256;
    using Math for int256;

    function _abs(int256 a) external pure returns (uint256) {
        return a.abs();
    }

    function _sqrt(uint256 x) external pure returns (uint256 result) {
        return x.sqrt();
    }

    function _fpsqrt(uint256 a) external pure returns (uint256 result) {
        return a.fpsqrt();
    }
}
