// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

interface IRewardConfigurator {
  struct PoolInitData {
    address provider;
    address impl;
    string poolName;
    uint256 initialRate;
    uint32 boostFactor;
    uint16 baselinePercentage;
  }

  struct PoolUpdateData {
    address pool;
    address impl;
  }

  event RewardPoolInitialized(address indexed pool, address indexed provider, PoolInitData data);

  event RewardPoolUpgraded(address indexed pool, address impl);
}
