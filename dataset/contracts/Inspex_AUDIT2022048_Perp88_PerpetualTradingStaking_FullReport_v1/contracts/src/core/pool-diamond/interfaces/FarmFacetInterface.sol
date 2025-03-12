// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { StrategyInterface } from "../../../interfaces/StrategyInterface.sol";

interface FarmFacetInterface {
  function farm(address token, bool isRebalanceNeeded) external;

  function setStrategyOf(address token, StrategyInterface newStrategy) external;

  function setStrategyTargetBps(address token, uint64 targetBps) external;
}
