// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../oracle/OracleInterface.sol";

contract TestOracle is OracleInterface {
    uint8 internal immutable _decimals;
    int256 internal _answer;

    constructor(int256 initAnswer, uint8 decimals) {
        _decimals = decimals;
        _answer = initAnswer;
    }

    function updateAnswer(int256 answer) external {
        _answer = answer;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function latestAnswer() external view override returns (int256) {
        return _answer;
    }
}
