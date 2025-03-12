// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IEarningsOracle.sol";

contract MockEarningsOracle is IEarningsOracle {
    uint256 public immutable earnings;

    constructor() {
        earnings = 420;
    }

    function lastRound() external override view returns (uint256, uint256) {
        return (block.timestamp /1 days, earnings);
    }

    function getRound(uint256) external override view returns (uint256) {
        return earnings;
    }
}