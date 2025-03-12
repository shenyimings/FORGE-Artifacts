// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.6.12;

import {SafeMath} from '../dependencies/openzeppelin/contracts/SafeMath.sol';
import {BitUtils} from '../tools/math/BitUtils.sol';

import {IMarketAccessController} from '../access/interfaces/IMarketAccessController.sol';
import {MarketAccessBitmask} from '../access/MarketAccessBitmask.sol';
import {AccessFlags} from '../access/AccessFlags.sol';
import {IManagedRewardController, AllocationMode} from './interfaces/IRewardController.sol';
import {IRewardPool} from './interfaces/IRewardPool.sol';
import {IManagedRewardPool} from './interfaces/IManagedRewardPool.sol';
import {IRewardMinter} from '../interfaces/IRewardMinter.sol';
import {IRewardCollector} from './interfaces/IRewardCollector.sol';
import {Errors} from '../tools/Errors.sol';

import 'hardhat/console.sol';

abstract contract BaseRewardController is
  IRewardCollector,
  MarketAccessBitmask,
  IManagedRewardController
{
  using SafeMath for uint256;

  IRewardMinter private _rewardMinter;

  IManagedRewardPool[] private _poolList;
  /* IManagedRewardPool => mask */
  mapping(address => uint256) private _poolMask;
  /* holder => masks of related pools */
  mapping(address => uint256) private _memberOf;

  uint256 private _ignoreMask;
  uint256 private _baselineMask;

  bool private _paused;

  constructor(IMarketAccessController accessController, IRewardMinter rewardMinter)
    public
    MarketAccessBitmask(accessController)
  {
    _rewardMinter = rewardMinter;
  }

  function _initialize(IMarketAccessController ac, IRewardMinter rewardMinter) internal {
    _remoteAcl = ac;
    _rewardMinter = rewardMinter;
  }

  function getAccessController() public view override returns (IMarketAccessController) {
    return _remoteAcl;
  }

  function addRewardPool(IManagedRewardPool pool) external override onlyConfigAdmin {
    require(address(pool) != address(0), 'reward pool required');
    require(_poolMask[address(pool)] == 0, 'already registered');
    require(_poolList.length <= 255, 'too many pools');

    uint256 poolMask = 1 << _poolList.length;
    _poolMask[address(pool)] = poolMask;
    _baselineMask |= poolMask;
    _poolList.push(pool);

    pool.attachedToRewardController(); // access check

    emit RewardPoolAdded(address(pool), poolMask);
  }

  function removeRewardPool(IManagedRewardPool pool) external override onlyConfigAdmin {
    require(address(pool) != address(0), 'reward pool required');
    uint256 poolMask = _poolMask[address(pool)];
    if (poolMask == 0) {
      return;
    }
    uint256 idx = BitUtils.bitLength(poolMask);
    require(_poolList[idx] == pool, 'unexpected pool');

    _poolList[idx] = IManagedRewardPool(0);
    delete (_poolMask[address(pool)]);
    _ignoreMask |= poolMask;

    internalOnPoolRemoved(pool);

    emit RewardPoolRemoved(address(pool), poolMask);
  }

  function getPoolMask(address pool) public view returns (uint256 poolMask) {
    poolMask = _poolMask[pool];
    if (poolMask & _ignoreMask != 0) {
      return 0;
    }
    return poolMask;
  }

  function internalOnPoolRemoved(IManagedRewardPool) internal virtual {}

  function updateBaseline(uint256 baseline)
    external
    override
    onlyRateAdmin
    returns (uint256 totalRate)
  {
    (totalRate, _baselineMask) = internalUpdateBaseline(baseline, _baselineMask);
    emit BaselineUpdated(baseline, totalRate, _baselineMask);
    return totalRate;
  }

  function internalUpdateBaseline(uint256 baseline, uint256 baselineMask)
    internal
    virtual
    returns (uint256 totalRate, uint256)
  {
    baselineMask &= ~_ignoreMask;

    for (uint8 i = 0; i <= 255; i++) {
      uint256 mask = uint256(1) << i;
      if (mask & baselineMask == 0) {
        if (mask > baselineMask) {
          break;
        }
        continue;
      }
      (bool hasBaseline, uint256 appliedRate) = _poolList[i].updateBaseline(baseline);
      if (appliedRate != 0 || hasBaseline) {
        totalRate += appliedRate;
        continue;
      }
      baselineMask &= ~mask;
    }
    return (totalRate, baselineMask);
  }

  function setRewardMinter(IRewardMinter minter) external override onlyConfigAdmin {
    _rewardMinter = minter;
    emit RewardMinterSet(address(minter));
  }

  function getPools()
    public
    view
    override
    returns (IManagedRewardPool[] memory, uint256 ignoreMask)
  {
    return (_poolList, _ignoreMask);
  }

  function getRewardMinter() external view returns (address) {
    return address(_rewardMinter);
  }

  function claimReward() external override notPaused returns (uint256 claimed, uint256 extra) {
    return _claimReward(msg.sender, ~uint256(0), msg.sender);
  }

  function claimRewardTo(address receiver)
    external
    override
    notPaused
    returns (uint256 claimed, uint256 extra)
  {
    require(receiver != address(0), 'receiver is required');
    return _claimReward(msg.sender, ~uint256(0), receiver);
  }

  function claimRewardFor(address holder, uint256 mask)
    external
    notPaused
    returns (uint256 claimed, uint256 extra)
  {
    require(holder != address(0), 'holder is required');
    return _claimReward(holder, mask, holder);
  }

  function claimableReward(address holder) public view returns (uint256 claimable, uint256 extra) {
    return _calcReward(holder, ~uint256(0));
  }

  function claimableRewardFor(address holder, uint256 mask)
    public
    view
    returns (uint256 claimable, uint256 extra)
  {
    require(holder != address(0), 'holder is required');
    return _calcReward(holder, mask);
  }

  function balanceOf(address holder) external view override returns (uint256) {
    if (holder == address(0)) {
      return 0;
    }
    (uint256 claimable, uint256 extra) = _calcReward(holder, ~uint256(0));
    return claimable.add(extra);
  }

  function claimablePools(address holder) external view returns (uint256) {
    return _memberOf[holder] & ~_ignoreMask;
  }

  function allocatedByPool(
    address holder,
    uint256 allocated,
    uint32 since,
    AllocationMode mode
  ) external override {
    uint256 poolMask = _poolMask[msg.sender];
    require(poolMask != 0, 'unknown pool');

    if (allocated > 0) {
      internalAllocatedByPool(holder, allocated, msg.sender, since);
      emit RewardsAllocated(holder, allocated, msg.sender);
    }

    if (mode == AllocationMode.Push) {
      return;
    }

    uint256 pullMask = _memberOf[holder];
    if (mode == AllocationMode.UnsetPull) {
      if (pullMask & poolMask != 0) {
        _memberOf[holder] = pullMask & ~poolMask;
      }
    } else {
      if (pullMask & poolMask != poolMask) {
        _memberOf[holder] = pullMask | poolMask;
      }
    }
  }

  function isRateAdmin(address addr) public view override returns (bool) {
    if (!hasRemoteAcl()) {
      return addr == address(this);
    }
    return acl_hasAnyOf(addr, AccessFlags.REWARD_RATE_ADMIN | AccessFlags.REWARD_CONFIGURATOR);
  }

  function _onlyRateAdmin() private view {
    require(isRateAdmin(msg.sender), Errors.CT_CALLER_MUST_BE_REWARD_RATE_ADMIN);
  }

  modifier onlyRateAdmin {
    _onlyRateAdmin();
    _;
  }

  function isConfigAdmin(address addr) public view override returns (bool) {
    if (!hasRemoteAcl()) {
      return addr == address(this);
    }
    return acl_hasAnyOf(addr, AccessFlags.REWARD_CONFIGURATOR | AccessFlags.REWARD_CONFIG_ADMIN);
  }

  function _onlyConfigAdmin() private view {
    require(isConfigAdmin(msg.sender), Errors.CT_CALLER_MUST_BE_REWARD_ADMIN);
  }

  modifier onlyConfigAdmin {
    _onlyConfigAdmin();
    _;
  }

  function _onlyConfigOrRateAdmin() private view {
    require(
      isConfigAdmin(msg.sender) || isRateAdmin(msg.sender),
      Errors.CT_CALLER_MUST_BE_REWARD_RATE_ADMIN
    );
  }

  modifier onlyConfigOrRateAdmin {
    _onlyConfigOrRateAdmin();
    _;
  }

  function isEmergencyAdmin(address addr) public view override returns (bool) {
    if (!hasRemoteAcl()) {
      return addr == address(this);
    }
    return acl_hasAllOf(addr, AccessFlags.EMERGENCY_ADMIN);
  }

  function getClaimMask(address holder, uint256 mask) internal view virtual returns (uint256) {
    mask &= ~_ignoreMask;
    mask &= _memberOf[holder];
    return mask;
  }

  function getPool(uint256 index) internal view returns (IManagedRewardPool) {
    return _poolList[index];
  }

  function _claimReward(
    address holder,
    uint256 mask,
    address receiver
  ) private returns (uint256 claimed, uint256 extra) {
    mask = getClaimMask(holder, mask);
    (claimed, extra) = internalClaimAndMintReward(holder, mask);

    // console.log('RewardsClaimed', claimed);
    if (claimed > 0) {
      extra += internalClaimed(holder, receiver, claimed);
      emit RewardsClaimed(holder, receiver, claimed);
    }
    return (claimed, extra);
  }

  function internalClaimed(
    address holder,
    address mintTo,
    uint256 amount
  ) internal virtual returns (uint256) {
    holder;
    internalMint(mintTo, amount, false);
    return 0;
  }

  function internalMint(
    address mintTo,
    uint256 amount,
    bool serviceAccount
  ) internal {
    _rewardMinter.mintReward(mintTo, amount, serviceAccount);
  }

  function internalClaimAndMintReward(address holder, uint256 mask)
    internal
    virtual
    returns (uint256 claimed, uint256 extra);

  function _calcReward(address holder, uint256 mask)
    private
    view
    returns (uint256 claimableAmount, uint256 extraAmount)
  {
    mask = getClaimMask(holder, mask);
    return internalCalcClaimableReward(holder, mask);
  }

  function internalCalcClaimableReward(address holder, uint256 mask)
    internal
    view
    virtual
    returns (uint256 claimableAmount, uint256 extraAmount);

  function internalAllocatedByPool(
    address holder,
    uint256 allocated,
    address pool,
    uint32 since
  ) internal virtual;

  function _notPaused() private view {
    require(!_paused, Errors.RW_REWARD_PAUSED);
  }

  modifier notPaused() {
    _notPaused();
    _;
  }

  function setPaused(bool paused) public override onlyEmergencyAdmin {
    _paused = paused;
    emit EmergencyPaused(msg.sender, paused);
  }

  function isPaused() public view override returns (bool) {
    return _paused;
  }
}
