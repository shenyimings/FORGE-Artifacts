// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.12;

interface IVoteEscrowLocker {
  event VoteEscrowLock(address indexed account, uint256 amount, uint256 durationInWeeks, uint256 previousUnlockAt, uint256 unlockAt, uint256 previousBalance, uint256 balance);
  event VoteEscrowUnlock(address indexed account, uint256 amount, uint256 unlockAt, uint256 penalty);

  error InvalidVoteLockPeriodError(uint256 min, uint256 max);
  error InvalidVoteLockExtensionError(uint256 min, uint256 proposed);
}
