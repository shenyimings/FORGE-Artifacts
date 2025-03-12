// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SafeMath} from '../../dependencies/openzeppelin/contracts/SafeMath.sol';
import {WadRayMath} from '../../tools/math/WadRayMath.sol';
import {BitUtils} from '../../tools/math/BitUtils.sol';

import {AllocationMode} from '../interfaces/IRewardController.sol';
import {RewardedTokenLocker} from './RewardedTokenLocker.sol';
import 'hardhat/console.sol';

import {IRewardController, AllocationMode} from '../interfaces/IRewardController.sol';

contract DecayingTokenLocker is RewardedTokenLocker {
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
    RewardedTokenLocker(
      controller,
      initialRate,
      baselinePercentage,
      underlying,
      pointPeriod,
      maxValuePeriod,
      maxWeightBase
    )
  {}

  function balanceOf(address account) public view virtual override returns (uint256) {
    (uint32 startTS, uint32 endTS) = expiryOf(account);
    uint32 current = getCurrentTick();
    if (current >= endTS) {
      return 0;
    }

    uint256 stakeAmount = getStakeBalance(account);
    uint256 stakeDecayed = stakeAmount.mul(endTS - current).div(endTS - startTS);

    if (stakeDecayed >= stakeAmount) {
      return stakeAmount;
    }
    return stakeDecayed;
  }

  function internalCalcReward(address holder)
    internal
    view
    override
    returns (uint256 amount, uint32 since)
  {
    (uint32 startTS, uint32 endTS) = expiryOf(holder);
    if (endTS == 0) {
      return (0, 0);
    }

    uint256 stakeAmount;
    uint32 current = getCurrentTick();
    if (current >= endTS) {
      // this is to emulate claimReward using calcCompensatedDecay when a balance has expired
      stakeAmount = getStakeBalance(holder);
      current = endTS;
    }

    (amount, since) = super.doCalcRewardAt(holder, current);
    if (amount == 0) {
      return (0, 0);
    }

    //    console.log('internalCalcReward_1', amount, since, getExtraRate());
    uint256 decayAmount = amount.rayMul(calcDecayForReward(startTS, endTS, since, current));

    amount =
      amount -
      calcCompensatedDecay(
        holder,
        decayAmount,
        stakeAmount,
        totalSupply(),
        calcDecayTimeCompensation(startTS, endTS, since, current)
      );

    //    console.log('internalCalcReward_2', current - since, amount, decayAmount);

    if (amount == 0) {
      return (0, 0);
    }

    return (amount, since);
  }

  function internalGetReward(address holder, uint256 limit)
    internal
    virtual
    override
    returns (uint256 amount, uint32 since)
  {
    internalUpdate(true, 0);

    (uint32 startTS, uint32 endTS) = expiryOf(holder);
    if (endTS == 0) {
      return (0, 0);
    }

    uint256 stakeAmount; // cached value as it may not be available after removal

    uint256 maxAmount;
    uint32 current = getCurrentTick();
    if (current >= endTS) {
      current = endTS;
      (maxAmount, since) = super.doGetRewardAt(holder, current);
      stakeAmount = super.internalRemoveReward(holder);
    } else {
      (maxAmount, since) = super.doGetRewardAt(holder, current);
    }

    if (maxAmount == 0) {
      return (0, 0);
    }

    //    console.log('internalGetReward_1', maxAmount, since, getExtraRate());

    uint256 decayAmount = maxAmount.rayMul(calcDecayForReward(startTS, endTS, since, current));

    if (limit <= maxAmount && limit + decayAmount <= maxAmount) {
      amount = limit;
      // console.log('internalClaimReward (limit below decay)', decayAmount, limit);
    } else {
      amount =
        maxAmount -
        calcCompensatedDecay(
          holder,
          decayAmount,
          stakeAmount,
          internalCurrentTotalSupply(),
          calcDecayTimeCompensation(startTS, endTS, since, current)
        );

      //      console.log('internalGetReward_2', current - since, amount, decayAmount);

      // console.log(
      //   'internalClaimReward (compensated)',
      //   maxAmount,
      //   decayAmount,
      //   decayAmount - (maxAmount - amount)
      // );

      if (amount > limit) {
        // console.log('internalClaimReward (limit applied)', limit);
        amount = limit;
      }
    }

    //    console.log('internalClaimReward', maxAmount, maxAmount - amount, getExtraRate());
    if (maxAmount > amount) {
      //      console.log('internalClaimReward (excess)', maxAmount - amount);
      internalAddExcess(maxAmount - amount, since);
    }

    if (amount == 0) {
      return (0, 0);
    }

    return (amount, since);
  }

  function setStakeBalance(address holder, uint224 stakeAmount) internal override {
    // NB! Actually, total and balance for decay compensation should be taken before the update.
    // Not doing it will give more to a user who increases balance - so it is better.

    (uint256 amount, uint32 since, AllocationMode mode) =
      doUpdateReward(
        holder,
        0, /* doesn't matter */
        stakeAmount
      );

    amount = rewardForBalance(holder, stakeAmount, amount, since, uint32(block.timestamp));
    internalAllocateReward(holder, amount, since, mode);
  }

  function unsetStakeBalance(
    address holder,
    uint32 at,
    bool interim
  ) internal override {
    (uint256 amount, uint32 since) = doGetRewardAt(holder, at);
    uint256 stakeAmount = internalRemoveReward(holder);
    AllocationMode mode = AllocationMode.Push;

    if (!interim) {
      mode = AllocationMode.UnsetPull;
    } else if (amount == 0) {
      return;
    }

    amount = rewardForBalance(holder, stakeAmount, amount, since, at);
    internalAllocateReward(holder, amount, since, mode);
  }

  function rewardForBalance(
    address holder,
    uint256 stakeAmount,
    uint256 amount,
    uint32 since,
    uint32 at
  ) private returns (uint256) {
    if (amount == 0) {
      return 0;
    }
    (uint32 startTS, uint32 endTS) = expiryOf(holder);

    uint256 maxAmount = amount;
    uint256 decayAmount = maxAmount.rayMul(calcDecayForReward(startTS, endTS, since, at));

    amount =
      maxAmount -
      calcCompensatedDecay(
        holder,
        decayAmount,
        stakeAmount,
        internalCurrentTotalSupply(),
        calcDecayTimeCompensation(startTS, endTS, since, at)
      );

    if (maxAmount > amount) {
      internalAddExcess(maxAmount - amount, since);
    }
  }

  /// @notice Calculates a range integral of the linear decay
  /// @param startTS start of the decay interval (beginning of a lock)
  /// @param endTS start of the decay interval (ending of a lock)
  /// @param since start of an integration range
  /// @param current end of an integration range
  /// @return Decayed portion [RAY..0] of reward, result = 0 means no decay
  function calcDecayForReward(
    uint32 startTS,
    uint32 endTS,
    uint32 since,
    uint32 current
  ) public pure returns (uint256) {
    require(startTS > 0);
    require(startTS < endTS);
    require(startTS <= since);
    require(current <= endTS);
    require(since <= current);
    return
      ((uint256(since - startTS) + (current - startTS)) * WadRayMath.halfRAY) / (endTS - startTS);
  }

  /// @notice Calculates an approximate decay compensation to equalize outcomes from multiple intermediate claims vs one final claim due to excess redistribution
  /// @dev There is no checks as it is invoked only after calcDecayForReward
  /// @param startTS start of the decay interval (beginning of a lock)
  /// @param endTS start of the decay interval (ending of a lock)
  /// @param since timestamp of a previous claim or start of the decay interval
  /// @param current timestamp of a new claim
  /// @return Compensation portion [RAY..0] of reward, result = 0 means no compensation
  function calcDecayTimeCompensation(
    uint32 startTS,
    uint32 endTS,
    uint32 since,
    uint32 current
  ) public pure returns (uint256) {
    // parabolic approximation
    return ((uint256(current - since)**2) * WadRayMath.RAY) / (uint256(endTS - startTS)**2);

    // uint32 width = endTS - startTS;
    // // logariphmic component to give a large compensation for longer distance between (since) and (current)
    // // bitLength provides a cheap alternative of log(x) when x is expanded to more bits
    // uint256 v = (255 - BitUtils.bitLength((type(uint256).max / width) * (width - (current - since)))) * WadRayMath.RAY / 255;
    // v *= 7;

    // // linear component to give a small non-zero compensation for smaller distance between (since) and (current)
    // v += uint256(current - since) * WadRayMath.RAY / width;

    // return v>>3;
  }

  function calcCompensatedDecay(
    address holder,
    uint256 decayAmount,
    uint256 stakeAmount,
    uint256 stakedTotal,
    uint256 compensationRatio
  ) public view returns (uint256) {
    // console.log('calcCompensatedDecay', decayAmount, stakeAmount, compensationRatio);
    if (decayAmount == 0 || compensationRatio == 0) {
      return decayAmount;
    }

    if (stakeAmount == 0) {
      // is included in the total
      stakeAmount = getStakeBalance(holder);
    } else {
      // is excluded from the total
      stakedTotal += stakeAmount;
    }

    if (stakedTotal > stakeAmount) {
      compensationRatio = (compensationRatio * stakeAmount) / stakedTotal;
    }

    if (compensationRatio >= WadRayMath.RAY) {
      return 0;
    }

    return decayAmount.rayMul(WadRayMath.RAY - compensationRatio);
  }
}
