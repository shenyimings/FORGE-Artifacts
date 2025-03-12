// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SafeMath} from '../../dependencies/openzeppelin/contracts/SafeMath.sol';
import {WadRayMath} from '../../tools/math/WadRayMath.sol';

import {BaseTokenLocker} from './BaseTokenLocker.sol';
import {IBoostRate} from '../interfaces/IBoostRate.sol';
import {ControlledRewardPool} from '../pools/ControlledRewardPool.sol';
import {CalcCheckpointWeightedReward} from '../calcs/CalcCheckpointWeightedReward.sol';
import {IBoostExcessReceiver} from '../interfaces/IBoostExcessReceiver.sol';
import {IRewardController, AllocationMode} from '../interfaces/IRewardController.sol';
import '../interfaces/IAutolocker.sol';

import {Errors} from '../../tools/Errors.sol';

import 'hardhat/console.sol';

contract RewardedTokenLocker is
  BaseTokenLocker,
  ControlledRewardPool,
  CalcCheckpointWeightedReward,
  IBoostExcessReceiver,
  IBoostRate,
  IAutolocker
{
  using SafeMath for uint256;
  using WadRayMath for uint256;

  constructor(
    IRewardController controller,
    uint256 initialRate,
    uint16 baselinePercentage,
    address underlying,
    uint32 pointPeriod,
    uint32 maxValuePeriod,
    uint256 maxWeightBase
  )
    public
    CalcCheckpointWeightedReward(maxWeightBase)
    BaseTokenLocker(underlying, pointPeriod, maxValuePeriod)
    ControlledRewardPool(controller, initialRate, baselinePercentage)
  {}

  function redeem(address to) public override notPaused returns (uint256 underlyingAmount) {
    return super.redeem(to);
  }

  function isRedeemable() external view returns (bool) {
    return !isPaused();
  }

  function addRewardProvider(address, address) external override onlyConfigAdmin {
    revert('UNSUPPORTED');
  }

  function removeRewardProvider(address) external override onlyConfigAdmin {}

  function internalSyncRate(uint32 at) internal override {
    // console.log('internalSyncRate', at, getExtraRate(), getStakedTotal());
    doSyncRateAt(at);
  }

  function internalCheckpoint(uint32 at) internal override {
    // console.log('internalCheckpoint', at, getExtraRate(), getStakedTotal());
    doCheckpoint(at);
  }

  function setStakeBalance(address holder, uint224 stakeAmount) internal virtual override {
    (uint256 amount, uint32 since, AllocationMode mode) =
      doUpdateReward(
        holder,
        0, /* doesn't matter */
        stakeAmount
      );
    internalAllocateReward(holder, amount, since, mode);
  }

  function unsetStakeBalance(
    address holder,
    uint32 at,
    bool interim
  ) internal virtual override {
    (uint256 amount, uint32 since) = doGetRewardAt(holder, at);
    internalRemoveReward(holder);
    AllocationMode mode = AllocationMode.Push;

    if (!interim) {
      mode = AllocationMode.UnsetPull;
    } else if (amount == 0) {
      return;
    }
    internalAllocateReward(holder, amount, since, mode);
  }

  function getStakeBalance(address holder) internal view override returns (uint224) {
    return getRewardEntry(holder).rewardBase;
  }

  function isHistory(uint32 at) internal view override returns (bool) {
    return isCompletedPast(at);
  }

  function internalExtraRate() internal view override returns (uint256) {
    return getExtraRate();
  }

  function internalTotalSupply() internal view override returns (uint256) {
    return getStakedTotal();
  }

  function balanceOf(address account) public view virtual override returns (uint256 stakeAmount) {
    (, uint32 expiry) = expiryOf(account);
    if (getCurrentTick() >= expiry) {
      return 0;
    }
    return getStakeBalance(account);
  }

  function internalCalcReward(address holder)
    internal
    view
    virtual
    override
    returns (uint256 amount, uint32 since)
  {
    (, uint32 expiry) = expiryOf(holder);
    if (expiry == 0) {
      return (0, 0);
    }
    uint32 current = getCurrentTick();
    if (current > expiry) {
      current = expiry;
    }
    return doCalcRewardAt(holder, current);
  }

  function internalGetReward(address holder, uint256 limit)
    internal
    virtual
    override
    returns (uint256 amount, uint32 since)
  {
    internalUpdate(true, 0);

    (, uint32 expiry) = expiryOf(holder);
    if (expiry == 0) {
      return (0, 0);
    }
    uint32 current = getCurrentTick();
    if (current < expiry) {
      (amount, since) = doGetRewardAt(holder, current);
    } else {
      (amount, since) = doGetRewardAt(holder, expiry);
      internalRemoveReward(holder);
    }

    if (amount > limit) {
      internalAddExcess(amount - limit, since);
      return (limit, since);
    }
    return (amount, since);
  }

  function internalGetRate() internal view override returns (uint256) {
    return getLinearRate();
  }

  function internalSetRate(uint256 rate) internal override {
    internalUpdate(false, 0);
    setLinearRate(rate);
  }

  function getCurrentTick() internal view override returns (uint32) {
    return uint32(block.timestamp);
  }

  function setBoostRate(uint256 rate) external override onlyController {
    _setRate(rate);
  }

  function receiveBoostExcess(uint256 amount, uint32 since) external override onlyController {
    internalUpdate(false, 0);
    internalAddExcess(amount, since);
  }

  function applyAutolock(
    address account,
    uint256 amount,
    AutolockMode mode,
    uint32 lockDuration,
    uint224 param
  )
    external
    override
    onlyController
    returns (
      address, /* receiver */
      uint256, /* lockAmount */
      bool stop
    )
  {
    uint256 recoverableError;
    if (mode == AutolockMode.Prolongate) {
      // full amount is locked
    } else if (mode == AutolockMode.AccumulateTill) {
      // full amount is locked
      if (block.timestamp >= param) {
        stop = true;
        amount = 0;
      }
    } else if (mode == AutolockMode.AccumulateUnderlying) {
      (amount, stop) = calcAutolockUnderlying(amount, balanceOfUnderlying(account), param);
    } else if (mode == AutolockMode.KeepUpBalance) {
      if (lockDuration == 0) {
        // shouldn't happen
        stop = true;
        amount = 0;
      } else {
        // it never stops unless the lock expires
        amount = calcAutolockKeepUp(amount, balanceOf(account), param, lockDuration);
      }
    } else {
      return (address(0), 0, false);
    }

    if (amount == 0) {
      return (address(0), 0, stop);
    }

    // NB! the tokens are NOT received here and must be minted to this locker directly
    (, recoverableError) = internalLock(address(this), account, amount, lockDuration, 0, false);

    if (recoverableError != 0) {
      emit RewardAutolockFailed(account, mode, recoverableError);
      return (address(0), 0, true);
    }

    return (address(this), amount, stop);
  }

  function calcAutolockUnderlying(
    uint256 amount,
    uint256 balance,
    uint256 limit
  ) private pure returns (uint256, bool) {
    if (balance >= limit) {
      return (0, true);
    }
    limit -= balance;

    if (amount > limit) {
      return (limit, true);
    }
    return (amount, amount == limit);
  }

  function calcAutolockKeepUp(
    uint256 amount,
    uint256 balance,
    uint256 limit,
    uint32 lockDuration
  ) private view returns (uint256) {
    if (balance >= limit) {
      return 0;
    }

    limit = convertLockedToUnderlying(limit - balance, lockDuration);

    if (amount > limit) {
      return limit;
    }
    return amount;
  }
}
