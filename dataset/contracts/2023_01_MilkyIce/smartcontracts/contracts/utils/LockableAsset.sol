// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @param durationInSeconds lock duration in seconds
 * @param rewardModifier reward modifier in basis points
 */
struct LockPeriod {
  uint256 durationInSeconds;
  uint256 rewardModifier;
}

/**
 * @dev Struct to hold the lockable asset information.
 * @param token The address of the token that can be locked.
 * @param isEntitledToVote Whether the lockable asset is entitled to vote.
 * @param lockPeriods The lock periods availible for the particular asset. Lock period is the
 * duration of the lock in seconds and the reward modifier in basis points (10000 = 100% = x1.0).
 * @param isLPToken Whether the lockable asset is an LP token.
 * @param dividendTokenFromPair Address of the token that is used to calculate the dividend for the LP token.
 * @param priceOracle Address of the price oracle for the LP token.
 */
struct LockableAsset {
  address token;
  bool isEntitledToVote;
  LockPeriod[] lockPeriods;
  bool isLPToken;
  // LP token specific properties
  address dividendTokenFromPair;
  address priceOracle;
}
