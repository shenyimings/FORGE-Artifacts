// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/contracts/access/AccessControl.sol';
import {Staking} from './Staking.sol';
import '../gelatoAutomate/OpsReady.sol';

error PeriodStarter__TimestampIsInPast();
error PeriodStarter__CurrentPeriodNotYetFinished();
error PeriodStarter__PeriodDurationCannotBe0();
error PeriodStarter__NewTimestampIsOlderThanExistingOne();
error PeriodStarter__TaskAlreadyCreated();

contract PeriodStarter is AccessControl, OpsReady {
  Staking public immutable stakingContract;

  uint256 public nextStakingPeriodFinishAt;
  uint256 public nextPeriodRewardsAmount;

  bytes32 public constant SCHEDULER_ROLE = keccak256('SCHEDULER_ROLE');

  constructor(address _ops, Staking _stakingContract) OpsReady(_ops, address(this)) {
    stakingContract = _stakingContract;
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  // ======== AUTOMATION FUNCTIONS ========

  function createTask() external override onlyRole(DEFAULT_ADMIN_ROLE) {
    super._createTask(
      address(this),
      abi.encodeCall(this.canStartNewRewardsPeriod, ()),
      address(this),
      abi.encode(this.startNewRewardsPeriod.selector)
    );
  }

  function cancelTask() external override onlyRole(DEFAULT_ADMIN_ROLE) {
    super._cancelTask();
  }

  // ======== PUBLIC FUNCTIONS ========

  function withdrawFunds(address owner) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _withdrawNativeToken(payable(owner));
  }

  function scheduleNextRewardsPeriod(
    uint256 _nextPeriodFinishTimestamp,
    uint256 _nextPeriodRewardsAmount
  ) external onlyRole(SCHEDULER_ROLE) {
    if (block.timestamp >= _nextPeriodFinishTimestamp) {
      revert PeriodStarter__TimestampIsInPast();
    }
    uint256 currentPeriodFinishAt = stakingContract.finishAt();
    if (currentPeriodFinishAt > _nextPeriodFinishTimestamp) {
      revert PeriodStarter__NewTimestampIsOlderThanExistingOne();
    }
    nextStakingPeriodFinishAt = _nextPeriodFinishTimestamp;
    nextPeriodRewardsAmount = _nextPeriodRewardsAmount;
  }

  /**
   * @notice Checks if the period starter can start a new rewards period.
   * @dev Automation service uses this function to check if the period starter can start a new rewards period.
   */
  function canStartNewRewardsPeriod()
    public
    view
    returns (bool canExec, bytes memory execPayload)
  {
    uint256 currentPeriodFinishAt = stakingContract.finishAt();
    if (currentPeriodFinishAt > block.timestamp) {
      return (false, 'Current period not yet finished');
    }
    return (true, abi.encodeCall(this.startNewRewardsPeriod, ()));
  }

  /**
   * @notice Starts a new rewards period.
   * @dev Can be called by anyone as the necessary checks are done in the _calculateNextPeriodDuration function and
   * inside the staking contract. All the parameters can be set only by the owner through scheduleNextRewardsPeriod
   * function.
   */
  function startNewRewardsPeriod() external automatedTask {
    uint256 nextPeriodDuration = _calculateNextPeriodDuration();
    stakingContract.startNewRewardsPeriod(nextPeriodDuration, nextPeriodRewardsAmount);
  }

  // ======== INTERNAL FUNCTIONS ========

  function _calculateNextPeriodDuration()
    internal
    view
    returns (uint256 nextPeriodDuration)
  {
    uint256 currentPeriodFinishAt = stakingContract.finishAt();
    if (currentPeriodFinishAt > block.timestamp) {
      revert PeriodStarter__CurrentPeriodNotYetFinished();
    }
    if (nextStakingPeriodFinishAt == currentPeriodFinishAt) {
      revert PeriodStarter__PeriodDurationCannotBe0();
    }

    nextPeriodDuration = nextStakingPeriodFinishAt - currentPeriodFinishAt;
  }
}
