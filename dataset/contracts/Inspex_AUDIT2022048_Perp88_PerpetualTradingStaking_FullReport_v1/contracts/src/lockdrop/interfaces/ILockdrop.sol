// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ILockdrop {
  function lockToken(uint256 amount, uint256 lockPeriod) external;

  function extendLockPeriod(uint256 lockPeriod) external;

  function addLockAmount(uint256 amount) external;

  function lockTokenFor(
    uint256 amount,
    uint256 lockPeriod,
    address user
  ) external;

  function extendLockPeriodFor(uint256 lockPeriod, address user) external;

  function addLockAmountFor(uint256 amount, address user) external;

  function earlyWithdrawLockedToken(uint256 amount, address user)
    external
    payable;

  function claimAllRewardsFor(address user, address receiver) external;

  function claimAllRewards(address user) external;

  function stakePLP() external;

  function withdrawAll(address user) external;

  function claimAllP88(address user) external returns (uint256);

  function lockdropStates(address user)
    external
    view
    returns (
      uint256 lockdropTokenAmount,
      uint256 lockPeriod,
      bool p88Claimed,
      bool restrictedWithdrawn
    );

  function lockdropConfig() external returns (address);
}
