// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.12;

import "./interfaces/IVoteEscrowLocker.sol";
import "../util/interfaces/IThrowable.sol";
import "./VoteEscrowTokenState.sol";

abstract contract VoteEscrowLocker is IThrowable, IVoteEscrowLocker, VoteEscrowTokenState {
  function _lock(address account, uint256 amount, uint256 durationInWeeks) internal {
    uint256 previousBalance = _balances[account];

    if (previousBalance == 0 && amount == 0) {
      // You need existing balance before you can extend the vote lock period
      revert ZeroAmountError("amount");
    }

    uint256 _MIN_LOCK_HEIGHT = 10;
    uint256 newUnlockTimestamp = block.timestamp + (durationInWeeks * 7 days);

    if (durationInWeeks < _MIN_LOCK_DURATION_IN_WEEKS || durationInWeeks > _MAX_LOCK_DURATION_IN_WEEKS) {
      revert InvalidVoteLockPeriodError(_MIN_LOCK_DURATION_IN_WEEKS, _MAX_LOCK_DURATION_IN_WEEKS);
    }

    if (newUnlockTimestamp < _unlockAt[account]) {
      // Can't decrease the lockup period
      revert InvalidVoteLockExtensionError(_unlockAt[account], newUnlockTimestamp);
    }

    emit VoteEscrowLock(account, amount, durationInWeeks, _unlockAt[account], newUnlockTimestamp, previousBalance, _balances[account]);

    _balances[account] += amount;
    _totalLocked += amount;
    _unlockAt[account] = newUnlockTimestamp;
    _minUnlockHeights[account] = block.number + _MIN_LOCK_HEIGHT;
  }

  function _unlock(address account, uint256 penalty) internal returns (uint256 amount) {
    amount = _balances[account];

    uint256 unlockAt = _unlockAt[account];

    if (amount == 0) {
      revert ZeroAmountError("balance");
    }

    delete _unlockAt[account];
    delete _balances[account];
    _totalLocked -= amount;

    emit VoteEscrowUnlock(account, amount, unlockAt, penalty);
  }
}
