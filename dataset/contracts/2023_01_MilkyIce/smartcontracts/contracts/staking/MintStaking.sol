// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';
import '../tokens/MintableToken.sol';
import '../staking/interfaces/IStaking.sol';

error Staking__StakeAmountCannotBe0();

/**
 * @notice Staking contract that is minting a fixed amount of rewards indefinately in ERC20 token
 * owned by the project creator
 * @dev This contract has to be able to mint rewards token. Additionally, this contract does not hold
 * any tokens, they are held on the MultiERC20WeightedLocker contract. This contract is only responsible
 * for minting reward tokens and keeping track of the rewards.
 */
contract MintStaking is IStaking, Ownable, ReentrancyGuard {
  event StakeDeposited(address indexed staker, uint256 amount, uint256 timestamp);
  event StakeWithdrawn(address indexed staker, uint256 amount, uint256 timestamp);
  event RewardsCollected(address indexed staker, uint256 amount, uint256 timestamp);

  IERC20 public immutable stakingToken;
  MintableToken public immutable rewardsToken;

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
  /// @notice Total amount staked
  uint256 public totalSupply;
  /// @dev User address => staked amount
  mapping(address => uint256) public balanceOf;

  constructor(address _stakingToken, address _rewardsToken, uint256 _rewardRate) {
    stakingToken = IERC20(_stakingToken);
    rewardsToken = MintableToken(_rewardsToken);
    rewardRate = _rewardRate;
  }

  // ======== MODIFIERS ========

  modifier updateReward(address _account) {
    rewardPerTokenStored = rewardPerToken();
    updatedAt = block.timestamp;

    if (_account != address(0)) {
      rewards[_account] = earnedReward(_account);
      userRewardPerTokenPaid[_account] = rewardPerTokenStored;
    }

    _;
  }

  // ======== VIEW FUNCTIONS ========

  function rewardPerToken() public view returns (uint256) {
    if (totalSupply == 0) {
      return rewardPerTokenStored;
    }

    return rewardPerTokenStored + rewardRate * (block.timestamp - updatedAt);
  }

  function earnedReward(address _account) public view override returns (uint256) {
    return
      ((balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) /
        1e18) + rewards[_account];
  }

  function getRewardToken() external view override returns (address) {
    return address(rewardsToken);
  }

  // ======== EXTERNAL FUNCTIONS ========

  function stakeFor(
    address _user,
    uint256 _amount
  ) external override updateReward(_user) nonReentrant onlyOwner {
    if (_amount == 0) {
      revert Staking__StakeAmountCannotBe0();
    }

    balanceOf[_user] += _amount;
    totalSupply += _amount;

    emit StakeDeposited(_user, _amount, block.timestamp);
  }

  function withdrawFor(
    address _user,
    uint256 _amount
  ) external override updateReward(_user) nonReentrant onlyOwner {
    if (_amount == 0) {
      revert Staking__StakeAmountCannotBe0();
    }

    balanceOf[_user] -= _amount;
    totalSupply -= _amount;

    emit StakeWithdrawn(_user, _amount, block.timestamp);
  }

  function collectRewardsFor(
    address _user
  )
    external
    override
    updateReward(_user)
    nonReentrant
    onlyOwner
    returns (uint256 reward)
  {
    reward = rewards[_user];
    if (reward > 0) {
      rewards[_user] = 0;
      rewardsToken.mint(_user, reward);
    }

    emit RewardsCollected(_user, reward, block.timestamp);
  }
}
