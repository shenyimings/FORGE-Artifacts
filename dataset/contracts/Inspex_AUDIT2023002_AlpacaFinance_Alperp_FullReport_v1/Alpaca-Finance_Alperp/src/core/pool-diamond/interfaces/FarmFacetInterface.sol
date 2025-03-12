// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/

pragma solidity 0.8.17;

import { StrategyInterface } from "../../../interfaces/StrategyInterface.sol";

interface FarmFacetInterface {
  function farm(address token, bool isRebalanceNeeded) external;

  function setStrategyOf(address token, StrategyInterface newStrategy) external;

  function setStrategyTargetBps(address token, uint64 targetBps) external;
}
