// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IBribe {

  function epoch() external view returns (uint);

  function getReward(
    address vault,
    uint veId,
    address[] memory tokens
  ) external;

  function getAllRewards(
    address vault,
    uint veId
  ) external;

  function getAllRewardsForTokens(
    address[] memory vaults,
    uint veId
  ) external;

  function deposit(address vault, uint amount, uint tokenId) external;

  function withdraw(address vault, uint amount, uint tokenId) external;

  function notifyRewardAmount(address vault, address token, uint amount) external;

  function notifyForNextEpoch(address vault, address token, uint amount) external;

  function notifyDelayedRewards(address vault, address token, uint _epoch) external;

  function increaseEpoch() external;
}
