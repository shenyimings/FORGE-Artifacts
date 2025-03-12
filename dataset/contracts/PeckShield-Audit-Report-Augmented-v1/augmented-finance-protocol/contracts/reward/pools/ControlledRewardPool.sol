// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.6.12;

import {SafeMath} from '../../dependencies/openzeppelin/contracts/SafeMath.sol';
import {WadRayMath} from '../../tools/math/WadRayMath.sol';
import {PercentageMath} from '../../tools/math/PercentageMath.sol';
import {IRewardController, AllocationMode} from '../interfaces/IRewardController.sol';
import {IManagedRewardPool} from '../interfaces/IManagedRewardPool.sol';
import {AccessFlags} from '../../access/AccessFlags.sol';
import {AccessHelper} from '../../access/AccessHelper.sol';
import {Errors} from '../../tools/Errors.sol';

import 'hardhat/console.sol';

abstract contract ControlledRewardPool is IManagedRewardPool {
  using SafeMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  uint16 internal constant NO_BASELINE = type(uint16).max;

  IRewardController internal _controller;

  uint256 private _pausedRate;
  uint16 private _baselinePercentage;
  bool private _paused;

  constructor(
    IRewardController controller,
    uint256 initialRate,
    uint16 baselinePercentage
  ) public {
    _initialize(controller, initialRate, baselinePercentage);
  }

  function _initialize(
    IRewardController controller,
    uint256 initialRate,
    uint16 baselinePercentage
  ) internal virtual {
    require(address(controller) != address(0), 'controller is required');
    _controller = controller;

    if (baselinePercentage == NO_BASELINE || (initialRate != 0 && baselinePercentage == 0)) {
      _baselinePercentage = NO_BASELINE;
      emit BaselineDisabled();
    } else if (baselinePercentage > 0) {
      internalSetBaselinePercentage(baselinePercentage);
    }

    if (initialRate > 0) {
      _setRate(initialRate);
    }
  }

  function getPoolName() public view virtual returns (string memory) {
    this;
    return '';
  }

  function updateBaseline(uint256 baseline)
    external
    virtual
    override
    onlyController
    returns (bool hasBaseline, uint256 appliedRate)
  {
    if (_baselinePercentage == NO_BASELINE) {
      return (false, internalGetRate());
    }
    appliedRate = baseline.percentMul(_baselinePercentage);
    _setRate(appliedRate);
    return (true, appliedRate);
  }

  function disableBaseline() external override onlyRateAdmin {
    _baselinePercentage = NO_BASELINE;
    emit BaselineDisabled();
  }

  function disableRewardPool() external override onlyRateAdmin {
    _baselinePercentage = NO_BASELINE;
    _pausedRate = 0;
    internalSetRate(0);
    emit BaselineDisabled();
    emit RateUpdated(0);
  }

  function setBaselinePercentage(uint16 factor) external override onlyRateAdmin {
    internalSetBaselinePercentage(factor);
  }

  function getBaselinePercentage() external view override returns (bool, uint16) {
    if (_baselinePercentage == NO_BASELINE) {
      return (false, 0);
    }
    return (true, _baselinePercentage);
  }

  function internalGetBaselinePercentage() internal view returns (uint16) {
    return _baselinePercentage;
  }

  function internalSetBaselinePercentage(uint16 factor) internal virtual {
    require(factor <= PercentageMath.ONE, 'illegal value');
    _baselinePercentage = factor;
    emit BaselineFactorUpdated(factor);
  }

  function setRate(uint256 rate) external override onlyRateAdmin {
    _setRate(rate);
  }

  function _setRate(uint256 rate) internal {
    if (isPaused()) {
      _pausedRate = rate;
      return;
    }
    internalSetRate(rate);
    emit RateUpdated(rate);
  }

  function getRate() external view override returns (uint256) {
    return internalGetRate();
  }

  function internalGetRate() internal view virtual returns (uint256);

  function internalSetRate(uint256 rate) internal virtual;

  function setPaused(bool paused) public override onlyEmergencyAdmin {
    if (_paused != paused) {
      _paused = paused;
      internalPause(paused);
    }
    emit EmergencyPaused(msg.sender, paused);
  }

  function isPaused() public view override returns (bool) {
    return _paused;
  }

  function internalPause(bool paused) internal virtual {
    if (paused) {
      _pausedRate = internalGetRate();
      internalSetRate(0);
      return;
    }
    internalSetRate(_pausedRate);
  }

  function getRewardController() public view override returns (address) {
    return address(_controller);
  }

  function claimRewardFor(address holder, uint256 limit)
    external
    override
    onlyController
    returns (uint256, uint32)
  {
    return internalGetReward(holder, limit);
  }

  function calcRewardFor(address holder) external view override returns (uint256, uint32) {
    return internalCalcReward(holder);
  }

  function internalAllocateReward(
    address holder,
    uint256 allocated,
    uint32 since,
    AllocationMode mode
  ) internal {
    _controller.allocatedByPool(holder, allocated, since, mode);
  }

  function internalGetReward(address holder, uint256 limit)
    internal
    virtual
    returns (uint256, uint32);

  function internalCalcReward(address holder) internal view virtual returns (uint256, uint32);

  function attachedToRewardController() external override onlyController {
    internalAttachedToRewardController();
  }

  function internalAttachedToRewardController() internal virtual {}

  function isController(address addr) internal view virtual returns (bool) {
    return address(_controller) == addr;
  }

  function _onlyController() private view {
    require(isController(msg.sender), Errors.CT_CALLER_MUST_BE_REWARD_CONTROLLER);
  }

  modifier onlyController() {
    _onlyController();
    _;
  }

  function _onlyConfigAdmin() private view {
    require(_controller.isConfigAdmin(msg.sender), Errors.CT_CALLER_MUST_BE_REWARD_ADMIN);
  }

  modifier onlyConfigAdmin() {
    _onlyConfigAdmin();
    _;
  }

  function _onlyRateAdmin() private view {
    require(_controller.isRateAdmin(msg.sender), Errors.CT_CALLER_MUST_BE_REWARD_RATE_ADMIN);
  }

  modifier onlyRateAdmin() {
    _onlyRateAdmin();
    _;
  }

  function _onlyEmergencyAdmin() private view {
    require(_controller.isEmergencyAdmin(msg.sender), Errors.CALLER_NOT_EMERGENCY_ADMIN);
  }

  modifier onlyEmergencyAdmin() {
    _onlyEmergencyAdmin();
    _;
  }

  function _onlyRefAdmin() private view {
    require(
      AccessHelper.hasAllOf(
        _controller.getAccessController(),
        msg.sender,
        AccessFlags.REFERRAL_ADMIN
      ),
      'only referral admin is allowed'
    );
  }

  modifier onlyRefAdmin() {
    _onlyRefAdmin();
    _;
  }

  function _notPaused() private view {
    require(!_paused, Errors.RW_REWARD_PAUSED);
  }

  modifier notPaused() {
    _notPaused();
    _;
  }
}
