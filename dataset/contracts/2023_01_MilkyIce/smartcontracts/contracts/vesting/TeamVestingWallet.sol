// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/contracts/finance/VestingWallet.sol';

/// @notice Vesting wallet for the team
contract TeamVestingWallet is VestingWallet {
  constructor(
    address _beneficiary,
    uint64 _startTimestamp,
    uint64 _durationInSeconds
  ) VestingWallet(_beneficiary, _startTimestamp, _durationInSeconds) {}
}
