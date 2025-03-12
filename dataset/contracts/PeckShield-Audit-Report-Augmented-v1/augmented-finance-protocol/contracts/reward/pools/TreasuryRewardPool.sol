// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.6.12;

import {SafeMath} from '../../dependencies/openzeppelin/contracts/SafeMath.sol';
import {WadRayMath} from '../../tools/math/WadRayMath.sol';
import {IRewardController, AllocationMode} from '../interfaces/IRewardController.sol';
import {IManagedRewardPool} from '../interfaces/IManagedRewardPool.sol';
import {ControlledRewardPool} from './ControlledRewardPool.sol';
import {CalcLinearRateAccum} from '../calcs/CalcLinearRateAccum.sol';

import 'hardhat/console.sol';

contract TreasuryRewardPool is ControlledRewardPool, CalcLinearRateAccum {
  address private _treasury;

  constructor(
    IRewardController controller,
    uint256 initialRate,
    uint16 baselinePercentage,
    address treasury
  ) public ControlledRewardPool(controller, initialRate, baselinePercentage) {
    require(treasury != address(0));
    _treasury = treasury;
  }

  function internalAttachedToRewardController() internal override {
    subscribeTreasury();
  }

  function subscribeTreasury() private {
    uint256 allocated = doGetAllReward(type(uint256).max);
    internalAllocateReward(_treasury, allocated, uint32(block.timestamp), AllocationMode.SetPull);
  }

  function internalSetRate(uint256 rate) internal override {
    super.setLinearRate(rate);
  }

  function internalGetRate() internal view override returns (uint256) {
    return super.getLinearRate();
  }

  function getCurrentTick() internal view override returns (uint32) {
    return uint32(block.timestamp);
  }

  function internalGetReward(address holder, uint256 limit)
    internal
    virtual
    override
    returns (uint256, uint32)
  {
    if (holder == _treasury) {
      return (doGetAllReward(limit), uint32(block.timestamp));
    }
    return (0, 0);
  }

  function internalCalcReward(address holder)
    internal
    view
    virtual
    override
    returns (uint256, uint32)
  {
    if (holder == _treasury) {
      return (doCalcRewardAt(uint32(block.timestamp)), uint32(block.timestamp));
    }
    return (0, 0);
  }

  function addRewardProvider(address, address) external override onlyConfigAdmin {
    revert('UNSUPPORTED');
  }

  function removeRewardProvider(address) external override onlyConfigAdmin {}
}
