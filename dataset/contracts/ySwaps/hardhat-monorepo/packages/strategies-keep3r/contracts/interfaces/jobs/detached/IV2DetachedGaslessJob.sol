// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import '../../../interfaces/jobs/v2/IV2Keeper.sol';

interface IV2DetachedGaslessJob {
  error NotZero();
  error StrategyAlreadyAdded();
  error StrategyNotAdded();
  error NotWorkable();

  // Setters
  event StrategiesAdded(address[] _strategies);
  event StrategiesRemoved(address[] _strategies);

  // Actions by Keeper
  event Worked(address _strategy, address _keeper);

  // Actions forced by governor
  event ForceWorked(address _strategy);

  // Getters
  function WETH() external view returns (address);

  function V2Keeper() external view returns (IV2Keeper);

  function lastWorkAt(address) external view returns (uint256);

  function workCooldown() external view returns (uint256);

  function callCost() external view returns (uint256);

  function strategies() external view returns (address[] memory);

  function workable(address _strategy) external view returns (bool);

  // Setters
  function setV2Keep3r(address _v2Keeper) external;

  function setWorkCooldown(uint256 _workCooldown) external;

  function setCallCost(uint256 _callCost) external;

  function addStrategies(address[] calldata _strategy) external;

  function removeStrategies(address[] calldata _strategy) external;

  // Keeper actions
  function work(address _strategy) external;

  // Mechanics keeper bypass
  function forceWork(address _strategy) external;
}
