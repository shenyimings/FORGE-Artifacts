// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../libs/math/LogExpMath.sol";

contract LogExpMathMock {
    using LogExpMath for *;

    function pow(uint256 x, uint256 y) external pure returns (uint256) {
        return x.pow(y);
    }

    function exp(int256 x) external pure returns (int256) {
        return LogExpMath.exp(x);
    }

    function log(int256 a, int256 b) external pure returns (int256) {
        return LogExpMath.log(a, b);
    }

    function ln(int256 x) external pure returns (int256) {
        return LogExpMath.ln(x);
    }
}
