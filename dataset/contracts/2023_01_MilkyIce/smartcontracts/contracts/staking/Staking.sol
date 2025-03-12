// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '../staking/interfaces/IStaking.sol';

error Staking__StakeAmountCannotBe0();
error Staking__WithdrawAmountCannotBe0();
error Staking__RewardsPeriodNotFinished();
error Staking__RewardRateIs0();
error Staking__WithdrawAmountBiggerThanStakedAmount();
error Staking__EmergencyWithdrawNotPossibleAfterRewardsPeriod();
error Staking__DurationExceedsMaxPeriodDuration();

/**
 * @notice Staking contract that is giving rewards in another ERC20 token that is not owned by the project creator
 * in defined time periods
 * @dev This contact has to have a sufficient rewards token balance in order to pay out rewards.
 * Additionally, this contract does not hold any user tokens, they are held on the MultiERC20WeightedLocker contract.
 * This contract is only responsible for keeping track of the rewards and it functions as a treasury for the reward
 * token.
 */
contract Staking is IStaking, AccessControl, ReentrancyGuard {
  using SafeERC20 for IERC20;

  event StakeDeposited(address indexed staker, uint256 amount, uint256 timestamp);
  event StakeWithdrawn(address indexed staker, uint256 amount, uint256 timestamp);
  event RewardsCollected(address indexed staker, uint256 amount, uint256 timestamp);
  event RewardsSlashed(address indexed staker, uint256 amount, uint256 timestamp);
  event RewardsPeriodStarted(
    uint256 startTimestamp,
    uint256 duration,
    uint256 finishTimestamp,
    uint256 rewardRate,
    uint256 rewardsAmount
  );

  bytes32 public constant LOCKER_ROLE = keccak256('LOCKER_ROLE');
  bytes32 public constant PERIOD_STARTER = keccak256('PERIOD_STARTER');

  IERC20 public immutable stakingToken;
  IERC20 public immutable rewardsToken;

  /// @notice Duration of rewards to be paid out (in seconds)
  uint256 public duration;
  /// @notice Timestamp of when the rewards period finishes
  uint256 public finishAt;
  /// @notice Minimum of last updated time and rewards period finish time
  uint256 public updatedAt;
  /// @notice Reward to be paid out per second
  uint256 public rewardRate;
  /// @dev Sum of (reward rate * delta * 1e18 / total supply)
  uint256 public rewardPerTokenStored;
  /// @dev User address => rewardPerTokenPaid
  mapping(address => uint256) public userRewardPerTokenPaid;
  /// @dev User address => rewards to be claimed
  mapping(address => uint256) public rewards;
  /// @dev maximum duration of rewards period
  uint256 public maxPeriodDuration = 365 days;

  /// @notice Amount of rewards to be paid out in current period
  uint256 public currentPeriodRewardsAmount;
  /// @notice Amount of rewards already paid out in current period
  uint256 public collectedRewardsInCurrentPeriod;

  /// @notice Total amount staked
  uint256 public totalSupply;
  /// @dev User address => staked amount
  mapping(address => uint256) public balanceOf;

  constructor(address _stakingToken, address _rewardToken) {
    stakingToken = IERC20(_stakingToken);
    rewardsToken = IERC20(_rewardToken);
    _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }

  // ======== MODIFIERS ========

  modifier updateReward(address _account) {
    rewardPerTokenStored = rewardPerToken();
    updatedAt = lastTimeRewardApplicable();

    if (_account != address(0)) {
      rewards[_account] = earnedReward(_account);
      userRewardPerTokenPaid[_account] = rewardPerTokenStored;
    }

    _;
  }

  // ======== VIEW FUNCTIONS ========

  function lastTimeRewardApplicable() public view returns (uint256) {
    // equivalent of Math.min(finishAt, blockTimestamp); for gas saving purposes
    return finishAt < block.timestamp ? finishAt : block.timestamp;
  }

  function rewardPerToken() public view returns (uint256) {
    if (totalSupply == 0) {
      return rewardPerTokenStored;
    }

    return
      rewardPerTokenStored +
      (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) /
      totalSupply;
  }

  function earnedReward(address _account) public view override returns (uint256) {
    return
      ((balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) /
        1e18) + rewards[_account];
  }

  function getRewardToken() external view override returns (address) {
    return address(rewardsToken);
  }

  // ======== PUBLIC FUNCTIONS ========

  function stakeFor(
    address _user,
    uint256 _amount
  ) public override updateReward(_user) onlyRole(LOCKER_ROLE) {
    if (_amount == 0) {
      revert Staking__StakeAmountCannotBe0();
    }

    balanceOf[_user] += _amount;
    totalSupply += _amount;

    emit StakeDeposited(_user, _amount, block.timestamp);
  }

  function collectRewardsFor(
    address _user
  )
    external
    override
    updateReward(_user)
    nonReentrant
    onlyRole(LOCKER_ROLE)
    returns (uint256 reward)
  {
    reward = rewards[_user];
    if (reward > 0) {
      rewards[_user] = 0;
      rewardsToken.safeTransfer(_user, reward);
    }
    collectedRewardsInCurrentPeriod += reward;

    emit RewardsCollected(_msgSender(), reward, block.timestamp);
  }

  function withdrawFor(
    address user,
    uint256 _amount
  ) external override updateReward(user) onlyRole(LOCKER_ROLE) {
    if (_amount == 0) {
      revert Staking__WithdrawAmountCannotBe0();
    }
    if (balanceOf[user] < _amount) {
      revert Staking__WithdrawAmountBiggerThanStakedAmount();
    }

    balanceOf[user] -= _amount;
    totalSupply -= _amount;

    emit StakeWithdrawn(user, _amount, block.timestamp);
  }

  // ======== GUARDED FUNCTIONS ========

  /// @notice Starts a new rewards period
  /// @dev This function is called by an external script right after the previous rewards period has finished.
  function startNewRewardsPeriod(
    uint256 _duration,
    uint256 _rewardsAmount
  ) external onlyRole(PERIOD_STARTER) updateReward(address(0)) {
    if (finishAt >= block.timestamp) {
      revert Staking__RewardsPeriodNotFinished();
    }
    _setRewardsDuration(_duration);
    _notifyRewardAmount(_rewardsAmount);

    emit RewardsPeriodStarted(
      block.timestamp,
      duration,
      finishAt,
      rewardRate,
      _rewardsAmount
    );
  }

  function _setRewardsDuration(uint256 _duration) internal {
    if (_duration > maxPeriodDuration) {
      revert Staking__DurationExceedsMaxPeriodDuration();
    }
    duration = _duration;
  }

  function _notifyRewardAmount(uint256 _amount) internal updateReward(address(0)) {
    if (block.timestamp >= finishAt) {
      rewardRate = _amount / duration;
    } else {
      uint remainingRewards = (finishAt - block.timestamp) * rewardRate;
      rewardRate = (_amount + remainingRewards) / duration;
    }

    if (rewardRate == 0) {
      revert Staking__RewardRateIs0();
    }

    finishAt = block.timestamp + duration;
    updatedAt = block.timestamp;
    currentPeriodRewardsAmount = _amount;
    collectedRewardsInCurrentPeriod = 0;
  }

  /// @notice Sets the maximum duration of rewards period
  /// @dev This function can be called only by the owner
  function setMaxPeriodDuration(
    uint256 _maxPeriodDuration
  ) external onlyRole(PERIOD_STARTER) {
    maxPeriodDuration = _maxPeriodDuration;
  }
}
