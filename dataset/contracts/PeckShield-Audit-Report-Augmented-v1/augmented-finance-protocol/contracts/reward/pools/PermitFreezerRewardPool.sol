// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.6.12;

import {SafeMath} from '../../dependencies/openzeppelin/contracts/SafeMath.sol';
import {WadRayMath} from '../../tools/math/WadRayMath.sol';
import {IRewardController, AllocationMode} from '../interfaces/IRewardController.sol';
import {IManagedRewardPool} from '../interfaces/IManagedRewardPool.sol';
import {BasePermitRewardPool} from './BasePermitRewardPool.sol';
import {CalcLinearFreezer} from '../calcs/CalcLinearFreezer.sol';

import 'hardhat/console.sol';

contract PermitFreezerRewardPool is BasePermitRewardPool, CalcLinearFreezer {
  uint256 private _rewardLimit;

  constructor(
    IRewardController controller,
    uint256 rewardLimit,
    uint32 meltDownAt,
    string memory rewardPoolName
  ) public BasePermitRewardPool(controller, 0, NO_BASELINE, rewardPoolName) {
    _rewardLimit = rewardLimit;
    internalSetMeltDownAt(meltDownAt);
  }

  function getClaimTypeHash() internal pure override returns (bytes32) {
    return
      keccak256(
        'ClaimReward(address provider,address spender,uint256 value,uint256 nonce,uint256 deadline)'
      );
  }

  function setFreezePercentage(uint32 freezePortion) external onlyConfigAdmin {
    internalSetFreezePercentage(freezePortion);
  }

  function setMeltDownAt(uint32 at) external onlyConfigAdmin {
    internalSetMeltDownAt(at);
  }

  function availableReward() public view override returns (uint256) {
    return _rewardLimit;
  }

  function claimRewardByPermit(
    address provider,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external notPaused {
    uint256 currentValidNonce = _nonces[spender];

    bytes32 encodedHash =
      keccak256(abi.encode(CLAIM_TYPEHASH, provider, spender, value, currentValidNonce, deadline));

    doClaimRewardByPermit(
      provider,
      spender,
      spender,
      value,
      deadline,
      encodedHash,
      currentValidNonce,
      v,
      r,
      s
    );
  }

  function internalCheckNonce(uint256 currentValidNonce, uint256 deadline)
    internal
    override
    returns (uint256)
  {
    require(block.timestamp <= deadline, 'INVALID_EXPIRATION');
    return currentValidNonce.add(1);
  }

  function internalGetReward(address holder, uint256)
    internal
    override
    returns (uint256 allocated, uint32)
  {
    (allocated, ) = doClaimByPull(holder, 0, 0);
    return (allocated, uint32(block.timestamp));
  }

  function internalCalcReward(address holder)
    internal
    view
    override
    returns (uint256 allocated, uint32)
  {
    (allocated, ) = doCalcByPull(holder, 0, 0, false);
    return (allocated, uint32(block.timestamp));
  }

  function internalPushReward(
    address holder,
    uint256 allocated,
    uint32 since
  ) internal override {
    AllocationMode mode;
    (allocated, since, mode) = doAllocatedByPush(holder, allocated, since);

    if (allocated == 0 && mode == AllocationMode.Push) {
      return;
    }
    internalAllocateReward(holder, allocated, since, mode);
  }

  function internalUpdateFunds(uint256 value) internal override {
    _rewardLimit = _rewardLimit.sub(value, 'INSUFFICIENT_FUNDS');
  }

  function internalSetBaselinePercentage(uint16) internal override {
    revert('UNSUPPORTED');
  }

  function internalSetRate(uint256 rate) internal override {
    if (rate != 0) {
      revert('UNSUPPORTED');
    }
  }

  function internalGetRate() internal view override returns (uint256) {
    return 0;
  }
}
