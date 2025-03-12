// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IStaking {
  function stakeFor(address _beneficiary, uint256 _amount) external;

  function withdrawFor(address _beneficiary, uint256 _amount) external;

  function collectRewardsFor(address _beneficiary) external returns (uint256);

  function earnedReward(address _beneficiary) external view returns (uint256);

  function getRewardToken() external view returns (address);
}
