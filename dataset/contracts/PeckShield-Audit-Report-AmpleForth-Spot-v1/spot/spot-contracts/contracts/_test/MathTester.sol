// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { Sigmoid } from "../_utils/Sigmoid.sol";

contract MathTester {
    function twoPower(int256 exp, int256 one) public pure returns (int256) {
        return Sigmoid.twoPower(exp, one);
    }

    function compute(int256 x, int256 lower, int256 upper, int256 growth, int256 one) public pure returns (int256) {
        return Sigmoid.compute(x, lower, upper, growth, one);
    }
}
