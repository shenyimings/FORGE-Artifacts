// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.12;

import "../dependencies/ABDKMath64x64.sol";
import "./VoteEscrowLocker.sol";

abstract contract VoteEscrowBooster is VoteEscrowLocker {
  using ABDKMath64x64 for uint256;
  using ABDKMath64x64 for int128;

  function _denominator() internal pure returns (uint256) {
    return 10_000;
  }

  function _calculateBoost(uint256 duration) internal pure returns (uint256) {
    uint256 boostFloor = 10_000;
    uint256 boostCeiling = 40_000;

    if (duration > _MAX_LOCK_DURATION_IN_WEEKS * 7 days) {
      return boostCeiling;
    }

    uint256 maxDurationInDays = _MAX_LOCK_DURATION_IN_WEEKS * 7;
    uint256 result = duration.divu(1 days).div(uint256(maxDurationInDays).fromUInt()).mul(boostCeiling.divu(_denominator()).log_2()).exp_2().mulu(_denominator());

    if (result < boostFloor) {
      return boostFloor;
    }

    if (result > boostCeiling) {
      return boostCeiling;
    }

    return result;
  }

  function _getVotingPower(uint256 balance, uint256 unlockTimestamp, uint256 currentTimestamp) internal pure returns (uint256) {
    if (unlockTimestamp <= currentTimestamp) {
      return balance;
    }

    return (balance * _calculateBoost(unlockTimestamp - currentTimestamp)) / _denominator();
  }
}
