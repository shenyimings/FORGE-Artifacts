// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILockStaking {
  function userStakedAmount(
    address user,
    uint256 round,
    address token
  ) external view returns (uint256);

  function poolStakedAmount(uint256 round, address tokenAddress)
    external
    view
    returns (uint256);

  function deposit(uint256 id, uint256 amount) external;
}
