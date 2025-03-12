// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IMultiPool {

  function totalSupply(address stakingToken) external view returns (uint);

  function derivedSupply(address stakingToken) external view returns (uint);

  function derivedBalances(address stakingToken, address account) external view returns (uint);

  function balanceOf(address stakingToken, address account) external view returns (uint);

  function rewardTokens(address stakingToken, uint id) external view returns (address);

  function isRewardToken(address stakingToken, address token) external view returns (bool);

  function rewardTokensLength(address stakingToken) external view returns (uint);

  function derivedBalance(address stakingToken, address account) external view returns (uint);

  function left(address stakingToken, address token) external view returns (uint);

  function earned(address stakingToken, address token, address account) external view returns (uint);

  function registerRewardToken(address stakingToken, address token) external;

  function removeRewardToken(address stakingToken, address token) external;

  function isStakeToken(address token) external view returns (bool);

}
