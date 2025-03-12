// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.6.12;

import {PercentageMath} from '../../tools/math/PercentageMath.sol';
import {IRewardController, AllocationMode} from '../interfaces/IRewardController.sol';
import {ControlledRewardPool} from './ControlledRewardPool.sol';
import {CalcLinearUnweightedReward} from '../calcs/CalcLinearUnweightedReward.sol';
import {Errors} from '../../tools/Errors.sol';

import 'hardhat/console.sol';

contract TeamRewardPool is ControlledRewardPool, CalcLinearUnweightedReward {
  using PercentageMath for uint256;

  address private _teamManager;
  uint32 private _lockupTill;
  uint16 private _totalShare;

  constructor(
    IRewardController controller,
    uint256 initialRate,
    uint16 baselinePercentage,
    address teamManager
  ) public ControlledRewardPool(controller, initialRate, baselinePercentage) {
    _teamManager = teamManager;
  }

  function _onlyTeamManagerOrConfigurator() private view {
    require(
      msg.sender == _teamManager || _controller.isConfigAdmin(msg.sender),
      Errors.CT_CALLER_MUST_BE_TEAM_MANAGER
    );
  }

  modifier onlyTeamManagerOrConfigurator {
    _onlyTeamManagerOrConfigurator();
    _;
  }

  function internalGetRate() internal view override returns (uint256) {
    return super.getLinearRate();
  }

  function internalSetRate(uint256 newRate) internal override {
    super.setLinearRate(newRate);
  }

  function internalGetReward(address holder, uint256) internal override returns (uint256, uint32) {
    if (!isUnlocked(getCurrentTick())) {
      return (0, 0);
    }
    return doGetReward(holder);
  }

  function internalCalcReward(address holder) internal view override returns (uint256, uint32) {
    if (!isUnlocked(getCurrentTick())) {
      return (0, 0);
    }
    return doCalcReward(holder);
  }

  function internalCalcRateAndReward(
    RewardEntry memory entry,
    uint256 lastAccumRate,
    uint32 currentBlock
  )
    internal
    view
    override
    returns (
      uint256 rate,
      uint256 allocated,
      uint32 since
    )
  {
    (rate, allocated, since) = super.internalCalcRateAndReward(entry, lastAccumRate, currentBlock);
    allocated = (allocated + PercentageMath.HALF_ONE) / PercentageMath.ONE;
    return (rate, allocated, since);
  }

  function addRewardProvider(address, address) external override onlyConfigAdmin {
    revert('UNSUPPORTED');
  }

  function removeRewardProvider(address) external override onlyConfigAdmin {}

  function getAllocatedShares() external view returns (uint16) {
    return _totalShare;
  }

  function isUnlocked(uint32 at) public view returns (bool) {
    return _lockupTill > 0 && _lockupTill < at;
  }

  function updateTeamMembers(address[] calldata members, uint16[] calldata memberSharePct)
    external
    onlyTeamManagerOrConfigurator
  {
    require(members.length == memberSharePct.length);
    for (uint256 i = 0; i < members.length; i++) {
      _updateTeamMember(members[i], memberSharePct[i]);
    }
  }

  function updateTeamMember(address member, uint16 memberSharePct)
    external
    onlyTeamManagerOrConfigurator
  {
    _updateTeamMember(member, memberSharePct);
  }

  function _updateTeamMember(address member, uint16 memberSharePct) private {
    require(member != address(0), 'member is required');
    require(memberSharePct <= PercentageMath.ONE, 'invalid share percentage');

    uint256 oldSharePct = getRewardEntry(member).rewardBase;
    uint256 newTotalShare = uint256(_totalShare) + memberSharePct - oldSharePct;
    require(newTotalShare <= PercentageMath.ONE, 'team total share exceeds 100%');
    _totalShare = uint16(newTotalShare);

    (uint256 allocated, uint32 since, AllocationMode mode) =
      doUpdateReward(member, oldSharePct, memberSharePct);

    require(
      allocated == 0 || isUnlocked(getCurrentTick()),
      'member share can not be changed during lockup'
    );

    internalAllocateReward(member, allocated, since, mode);
  }

  function removeTeamMember(address member) external onlyTeamManagerOrConfigurator {
    require(member != address(0), 'member is required');

    uint256 lastShare = internalRemoveReward(member);
    if (lastShare < _totalShare) {
      _totalShare -= uint16(lastShare);
    } else {
      _totalShare = 0;
    }
    internalAllocateReward(member, 0, 0, AllocationMode.UnsetPull);
  }

  function setTeamManager(address member) external onlyTeamManagerOrConfigurator {
    _teamManager = member;
  }

  function getTeamManager() external view returns (address) {
    return _teamManager;
  }

  function setUnlockedAt(uint32 at) external onlyConfigAdmin {
    require(at > 0, 'unlockAt is required');
    // console.log('setUnlockedAt', _lockupTill, getCurrentTick(), at);
    require(_lockupTill == 0 || _lockupTill >= getCurrentTick(), 'lockup is finished');
    _lockupTill = at;
  }

  function getUnlockedAt() external view returns (uint32) {
    return _lockupTill;
  }

  function getCurrentTick() internal view override returns (uint32) {
    return uint32(block.timestamp);
  }
}
