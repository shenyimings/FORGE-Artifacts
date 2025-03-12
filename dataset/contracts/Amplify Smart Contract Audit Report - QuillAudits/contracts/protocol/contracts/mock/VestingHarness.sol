// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../Vesting/Vesting.sol";

contract VestingHarness is Vesting {

    uint256 public blockTimestamp;

    function fastTimestamp(uint256 days_) external returns (uint256) {
        blockTimestamp += days_ * 24 * 60 * 60;
        return blockTimestamp;
    }

    function setBlockTimestamp(uint256 timestamp) external {
        blockTimestamp = timestamp;
    }

    function getBlockTimestamp() public override view returns (uint256) {
        return blockTimestamp;
    }
} 