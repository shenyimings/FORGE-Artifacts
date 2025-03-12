// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.6.12;

import {SafeMath} from '../../dependencies/openzeppelin/contracts/SafeMath.sol';
import {WadRayMath} from '../../tools/math/WadRayMath.sol';
import {BitUtils} from '../../tools/math/BitUtils.sol';
import {IRewardController} from '../interfaces/IRewardController.sol';
import {CalcLinearRateReward} from './CalcLinearRateReward.sol';

import 'hardhat/console.sol';

abstract contract CalcLinearWeightedReward is CalcLinearRateReward {
  using SafeMath for uint256;
  using WadRayMath for uint256;

  uint256 private _accumRate;
  uint256 private _totalSupply;

  uint256 private _maxWeightBase;
  uint256 private constant minBitReserve = 32;

  constructor(uint256 maxWeightBase) public {
    require(maxWeightBase > 0, 'max total supply is unknown');

    uint256 maxWeightBits = BitUtils.bitLength(maxWeightBase);
    require(maxWeightBits + minBitReserve < 256, 'max total supply is too high');

    _maxWeightBase = maxWeightBase; // (1 << maxWeightBits) - 1;
  }

  function doUpdateTotalSupplyDiff(uint256 oldSupply, uint256 newSupply) internal returns (bool) {
    if (newSupply > oldSupply) {
      return internalSetTotalSupply(_totalSupply.add(newSupply - oldSupply), getCurrentTick());
    }
    if (oldSupply > newSupply) {
      return internalSetTotalSupply(_totalSupply.sub(oldSupply - newSupply), getCurrentTick());
    }
    return false;
  }

  function doUpdateTotalSupply(uint256 newSupply) internal returns (bool) {
    if (newSupply == _totalSupply) {
      return false;
    }
    return internalSetTotalSupply(newSupply, getCurrentTick());
  }

  function doUpdateTotalSupplyAt(uint256 newSupply, uint32 at) internal returns (bool) {
    if (newSupply == _totalSupply) {
      return false;
    }
    return internalSetTotalSupply(newSupply, at);
  }

  function internalRateUpdated(
    uint256 lastRate,
    uint32 lastAt,
    uint32 at
  ) internal override {
    if (_totalSupply == 0) {
      return;
    }

    // the rate stays in RAY, but is weighted now vs _maxWeightBase
    if (at != lastAt) {
      lastRate = lastRate.mul(_maxWeightBase.div(_totalSupply));
      _accumRate = _accumRate.add(lastRate.mul(at - lastAt));
    }
  }

  function internalSetTotalSupply(uint256 totalSupply, uint32 at)
    internal
    returns (bool rateUpdated)
  {
    uint256 lastRate = getLinearRate();
    uint32 lastAt = getRateUpdatedAt();
    internalMarkRateUpdate(at);

    if (lastRate > 0) {
      internalRateUpdated(lastRate, lastAt, at);
      rateUpdated = lastAt != at;
    }

    _totalSupply = totalSupply;
    return rateUpdated;
  }

  function internalGetLastAccumRate() internal view returns (uint256) {
    return _accumRate;
  }

  function internalCalcRateAndReward(
    RewardEntry memory entry,
    uint256 lastAccumRate,
    uint32 at
  )
    internal
    view
    virtual
    override
    returns (
      uint256 adjRate,
      uint256 allocated,
      uint32 /* since */
    )
  {
    adjRate = _accumRate;

    if (_totalSupply > 0) {
      (uint256 rate, uint32 updatedAt) = getRateAndUpdatedAt();

      rate = rate.mul(_maxWeightBase.div(_totalSupply));
      adjRate = adjRate.add(rate.mul(at - updatedAt));
    }

    if (adjRate == lastAccumRate || entry.rewardBase == 0) {
      return (adjRate, 0, entry.claimedAt);
    }

    allocated = mulDiv(entry.rewardBase, adjRate.sub(lastAccumRate), _maxWeightBase);
    return (adjRate, allocated, entry.claimedAt);
  }

  function totalSupplyMax() internal view returns (uint256) {
    return _maxWeightBase;
  }
}
