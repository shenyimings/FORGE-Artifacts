// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.6.12;

interface IRewardMinter {
  /**
   * @dev mints a reward
   */
  function mintReward(
    address holder,
    uint256 amount,
    bool serviceAccount
  ) external;
}
