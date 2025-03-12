// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract MockLockdrop2 {
  uint256 public lockTokenForCallCount = 0;
  uint256 public extendLockPeriodForCallCount = 0;
  uint256 public addLockAmountForCallCount = 0;

  mapping(address => LockdropState) public lockdropStates;

  struct LockdropState {
    uint256 lockdropTokenAmount;
    uint256 lockPeriod;
    uint256[] userRewardDebts;
    bool p88Claimed;
    bool restrictedWithdrawn;
  }

  function lockTokenFor(
    uint256 amount,
    uint256 lockPeriod,
    address user
  ) external {
    lockdropStates[user].lockdropTokenAmount += amount;
    lockdropStates[user].lockPeriod = lockPeriod;
    lockTokenForCallCount++;
  }

  function extendLockPeriodFor(uint256 lockPeriod, address user) external {
    lockdropStates[user].lockPeriod = lockPeriod;
    extendLockPeriodForCallCount++;
  }

  function addLockAmountFor(uint256 amount, address user) external {
    lockdropStates[user].lockdropTokenAmount += amount;
    addLockAmountForCallCount++;
  }
}
