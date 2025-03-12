// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../util/interfaces/IThrowable.sol";
import "./LiquidityGaugePoolState.sol";

abstract contract LiquidityGaugePoolController is IThrowable, AccessControlUpgradeable, LiquidityGaugePoolState {
  modifier onlyRegistry() {
    if (_msgSender() != _poolInfo.registry) {
      revert AccessDeniedError("Registry");
    }

    _;
  }

  function _setPool(PoolInfo calldata args) internal {
    if (args.epochDuration > 0) {
      _poolInfo.epochDuration = args.epochDuration;
    }

    if (args.veBoostRatio > 0) {
      _poolInfo.veBoostRatio = args.veBoostRatio;
    }

    if (args.stakingToken != address(0)) {
      _poolInfo.stakingToken = args.stakingToken;
    }

    if (args.veToken != address(0)) {
      _poolInfo.veToken = args.veToken;
    }

    if (args.rewardToken != address(0)) {
      _poolInfo.rewardToken = args.rewardToken;
    }

    if (args.registry != address(0)) {
      _poolInfo.registry = args.registry;
    }

    if (args.treasury != address(0)) {
      _poolInfo.treasury = args.treasury;
    }

    if (args.key > 0) {
      _poolInfo.key = args.key;
    }

    if (bytes(args.name).length > 0) {
      _poolInfo.name = args.name;
    }

    if (bytes(args.info).length > 0) {
      _poolInfo.info = args.info;
    }

    if (args.lockupPeriodInBlocks > 0) {
      _poolInfo.lockupPeriodInBlocks = args.lockupPeriodInBlocks;
    }

    if (args.platformFee > 0) {
      _poolInfo.platformFee = args.platformFee;
    }

    emit LiquidityGaugePoolSet(_poolInfo.key, _msgSender(), address(this), args);
  }

  function _setEpochDuration(uint256 epochDuration) internal {
    emit EpochDurationUpdated(_poolInfo.key, _poolInfo.epochDuration, epochDuration);

    _poolInfo.epochDuration = epochDuration;
  }
}
