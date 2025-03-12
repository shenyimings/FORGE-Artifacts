// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.6.12;

import {SafeMath} from '../dependencies/openzeppelin/contracts/SafeMath.sol';
import {PercentageMath} from '../tools/math/PercentageMath.sol';

import {IMarketAccessController} from '../access/interfaces/IMarketAccessController.sol';
import {BasicRewardController} from './BasicRewardController.sol';
import {CalcLinearFreezer} from './calcs/CalcLinearFreezer.sol';
import {IRewardMinter} from '../interfaces/IRewardMinter.sol';

import 'hardhat/console.sol';

// TODO: remove after refactoring of tests
contract RewardFreezer is BasicRewardController, CalcLinearFreezer {
  using SafeMath for uint256;
  using PercentageMath for uint256;

  mapping(address => uint256) private _claimableRewards;

  constructor(IMarketAccessController accessController, IRewardMinter rewardMinter)
    public
    BasicRewardController(accessController, rewardMinter)
  {}

  function setFreezePercentage(uint32 freezePortion) external onlyConfigAdmin {
    internalSetFreezePercentage(freezePortion);
  }

  function setMeltDownAt(uint32 at) external onlyConfigAdmin {
    internalSetMeltDownAt(at);
  }

  function internalAllocatedByPool(
    address holder,
    uint256 allocated,
    address,
    uint32 since
  ) internal override {
    allocated = doAllocatedByPool(holder, allocated, since);
    if (allocated > 0) {
      _claimableRewards[holder] = _claimableRewards[holder].add(allocated);
    }
  }

  function internalClaimByCall(
    address holder,
    uint256 allocated,
    uint32 since
  ) internal override returns (uint256 claimableAmount, uint256 delayedAmount) {
    (claimableAmount, delayedAmount) = doClaimByPull(holder, allocated, since);

    uint256 claimableReward = _claimableRewards[holder];
    if (claimableReward > 0) {
      claimableAmount = claimableAmount.add(claimableReward);
      delete (_claimableRewards[holder]);
    }

    return (claimableAmount, delayedAmount);
  }

  function internalCalcByCall(
    address holder,
    uint256 allocated,
    uint32 since,
    bool incremental
  ) internal view override returns (uint256 claimableAmount, uint256 frozenReward) {
    (claimableAmount, frozenReward) = doCalcByPull(holder, allocated, since, incremental);
    claimableAmount = claimableAmount.add(_claimableRewards[holder]);
    return (claimableAmount, frozenReward);
  }
}
