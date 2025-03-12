// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "./interfaces/ILiquidityGaugePool.sol";

abstract contract LiquidityGaugePoolState is ILiquidityGaugePool {
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                           Version 1
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  bytes32 public constant _NS_ROLES_PAUSER = "role:pauser";
  bytes32 public constant _NS_ROLES_RECOVERY_AGENT = "role:recovery:agent";

  uint256 public _epoch;
  uint256 public _epochEndTimestamp;
  uint256 public _lastRewardTimestamp;
  uint256 public _lockedByEveryone;
  uint256 public _rewardPerSecond;
  uint256 public _rewardPerTokenUnit;
  uint256 public _totalVotingPower;

  PoolInfo public _poolInfo;

  mapping(address => uint256) public _lastDepositHeights;
  mapping(address => uint256) public _lastRewardPerTokenUnit;
  mapping(address => uint256) public _lockedByMe;
  mapping(address => uint256) public _myVotingPower;
  mapping(address => uint256) public _pendingRewardToDistribute;
}
