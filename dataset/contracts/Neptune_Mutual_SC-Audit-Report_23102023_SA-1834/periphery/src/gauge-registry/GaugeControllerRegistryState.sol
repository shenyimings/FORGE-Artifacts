// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interfaces/IGaugeControllerRegistry.sol";

abstract contract GaugeControllerRegistryState is IGaugeControllerRegistry {
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                           Version 1
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  bytes32 public constant _NS_GAUGE_AGENT = "role:gauge:agent";
  bytes32 public constant _NS_ROLES_PAUSER = "role:pauser";
  bytes32 public constant _NS_ROLES_RECOVERY_AGENT = "role:recovery:agent";

  uint256 public _epoch;
  uint256 public _sumAllocation;
  
  IERC20Upgradeable public _rewardToken;

  mapping(bytes32 => bool) public _activePools;
  mapping(bytes32 => bool) public _validPools;
  mapping(uint256 => uint256) public _epochDurations;
  mapping(uint256 => uint256) public _gaugeAllocations;
  mapping(bytes32 => ILiquidityGaugePool) public _pools;
}
