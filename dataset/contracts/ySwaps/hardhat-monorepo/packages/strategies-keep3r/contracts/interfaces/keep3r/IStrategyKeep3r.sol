// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import '@yearn-mechanics/contract-utils/solidity/interfaces/keep3r/IKeep3r.sol';

interface IStrategyKeep3r is IKeep3r {
  // Actions by Keeper
  event HarvestByKeeper(address _strategy);
  // Actions forced by governance
  event HarvestByGovernor(address _strategy);

  // Keep3r actions
  function harvest(address _strategy) external;

  // Governance Keeper bypass
  function forceHarvest(address _strategy) external;
}
