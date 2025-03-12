// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../staking/interfaces/IRewarder.sol";

contract MockRewarder is IRewarder {
  function name() external view returns (string memory) {}

  function rewardRate() external view returns (uint256) {}

  function onDeposit(address user, uint256 shareAmount) external {}

  function onWithdraw(address user, uint256 shareAmount) external {}

  function onHarvest(address user, address receiver) external {}

  function pendingReward(address user) external view returns (uint256) {
    return 0;
  }
}
