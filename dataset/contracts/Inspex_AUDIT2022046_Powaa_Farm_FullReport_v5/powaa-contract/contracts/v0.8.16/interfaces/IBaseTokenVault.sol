// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

interface IBaseTokenVault {
  // Views
  function balanceOf(address account) external view returns (uint256);

  function earned(address account) external view returns (uint256);

  function getRewardForDuration() external view returns (uint256);

  function lastTimeRewardApplicable() external view returns (uint256);

  function rewardPerToken() external view returns (uint256);

  function rewardsDistribution() external view returns (address);

  function rewardsToken() external view returns (address);

  function totalSupply() external view returns (uint256);

  function getMasterContractOwner() external view returns (address);

  function isGovLpVault() external view returns (bool);

  // Mutative

  function initialize(
    address _rewardsDistribution,
    address _rewardsToken,
    address _stakingToken,
    address _controller
  ) external;

  function exit() external;

  function claimGov() external;

  function stake(uint256 amount) external;

  function withdraw(uint256 amount) external;

  function migrate() external;
}
