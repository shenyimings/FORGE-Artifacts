//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./ITokenVestingEvent.sol";

interface ITokenVesting is ITokenVestingEvent {
    struct VestingSchedule {
        bool initialized;
        // beneficiary of tokens after they are released
        address beneficiary;
        // cliff period in seconds
        uint256 cliff;
        // start time of the vesting period
        uint256 start;
        // duration of the vesting period in seconds
        uint256 duration;
        // duration of a slice period for the vesting in seconds
        uint256 slicePeriodSeconds;
        // whether or not the vesting is revocable
        bool revocable;
        // Total number of tokens in vested
        uint256 amountTotal;
        // amount of tokens released
        uint256 released;
        // whether or not the vesting has been revoked
        bool revoked;
        // amount of token released upfront
        uint256 upFront;
    }
}
