// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.3.2 (finance/VestingWallet.sol)
pragma solidity ^0.8.9;

import "./VestingWallet.sol";


contract MonthlyVestingWallet is VestingWallet {
    uint64 public immutable _durationMonths;
    uint64 public immutable _cliffDurationMonths;
    uint64 public immutable _cliff;
    address public immutable _beneficiary;
    uint64 private _start;
    uint64 private _duration;

    uint64 constant internal SECONDS_PER_MONTH = 2628288;

    /**
     * @dev Set the beneficiary, start timestamp and vesting duration of the vesting wallet.
     */
    constructor(
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 cliffDurationMonths,
        uint64 durationMonths
    ) VestingWallet(beneficiaryAddress, startTimestamp, (durationMonths+1) * SECONDS_PER_MONTH) {
        require(beneficiaryAddress != address(0), "VestingWallet: beneficiary is zero address");
        _beneficiary = beneficiaryAddress;
        _start = startTimestamp;
        _durationMonths = durationMonths+1;
        _cliffDurationMonths = cliffDurationMonths;
        _duration = durationMonths * SECONDS_PER_MONTH;
        _cliff = _cliffDurationMonths * SECONDS_PER_MONTH;
    }

    /**
     * @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for
     * an asset given its total historical allocation.
     */
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view virtual override returns (uint256) {
        return totalAllocation * equalMonthlyVestingPercent(timestamp) / 10000;
    }

    /**
     * @dev Calculates the percentage of tokens that has already vested as a function of time.
     */
    function equalMonthlyVestingPercent(uint64 timestamp) public view returns (uint64) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp - start() < _cliff)  {
            return 0;
        } else if (timestamp > start() + duration() + uint256(_cliff) - SECONDS_PER_MONTH) {
            return 10000;
        }
        uint64 secondsAfterCliff = timestamp - _start - _cliff;
        uint64 step = (10000 / _durationMonths);
        return (step + (secondsAfterCliff * 10000 /  SECONDS_PER_MONTH /  _durationMonths)) / step * step;
    }





}