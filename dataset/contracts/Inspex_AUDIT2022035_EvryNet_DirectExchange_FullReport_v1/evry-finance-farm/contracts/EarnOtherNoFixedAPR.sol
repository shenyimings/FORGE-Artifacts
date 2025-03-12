//contracts/EarnOtherNoFixedAPR.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract EarnOtherNoFixedAPR is Ownable, ReentrancyGuard {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  /// @dev define from constructor
  uint256 public immutable startBlock;
  uint256 public rewardPerBlock;
  ERC20 public immutable stakedToken;
  ERC20 public immutable rewardToken;
  bool private immutable isMultiPool;
  uint256 private precisionFactor;

  /// @dev Pool accrued, total staked and last update from all users
  uint256 public totalStaked;
  uint256 public accTokenPerShare;
  uint256 public lastRewardBlock;

  // Info of each user that stakes tokens (stakedToken)
  mapping(address => UserInfo) public userInfo;

  struct UserInfo {
    uint256 amount;
    uint256 rewardDebt;
  }

  event Deposit(address indexed user, uint256 amount);
  event Withdraw(address indexed user, uint256 amount);
  event SetRewardPerBlock(uint256 rewardPerBlock);
  event Harvest(address indexed user, uint256 amount);
  event EmergencyWithdraw(address indexed user, uint256 amount);

  constructor(
    ERC20 _stakedToken,
    ERC20 _rewardToken,
    uint256 _rewardPerBlock,
    uint256 _startBlock,
    address _admin
  ) {
    stakedToken = _stakedToken;
    rewardToken = _rewardToken;
    rewardPerBlock = _rewardPerBlock;
    startBlock = _startBlock;

    // Set the lastRewardBlock as the startBlock
    lastRewardBlock = _startBlock;

    isMultiPool = (address(_stakedToken) != address(_rewardToken));
    precisionFactor =
      10**(_rewardToken.decimals() > _stakedToken.decimals() ? _rewardToken.decimals() : _stakedToken.decimals());

    transferOwnership(_admin);
  }

  /// @notice Specific amount user need to deposit and actual amount can be different due to token's tax or cap of this pool
  function deposit(uint256 _amount) external nonReentrant {
    UserInfo storage user = userInfo[msg.sender];

    _updatePool();

    if (user.amount > 0) {
      uint256 rewards = user.amount.mul(accTokenPerShare).div(precisionFactor).sub(user.rewardDebt);
      if (rewards > 0) {
        require(_isTransferable(rewards), "insufficient reward");
        rewardToken.safeTransfer(msg.sender, rewards);
      }
    }

    uint256 preAmount = stakedToken.balanceOf(address(this));
    stakedToken.safeTransferFrom(msg.sender, address(this), _amount);
    uint256 postAmount = stakedToken.balanceOf(address(this));
    uint256 actualAmount = postAmount.sub(preAmount);

    totalStaked = totalStaked.add(actualAmount);

    user.amount = user.amount.add(actualAmount);
    user.rewardDebt = user.amount.mul(accTokenPerShare).div(precisionFactor);

    emit Deposit(msg.sender, actualAmount);
  }

  /// @notice calculate reward that ready to be claimed
  function pendingReward(address _for) external view returns (uint256) {
    require(_for != address(0), "bad address");

    UserInfo storage user = userInfo[_for];
    uint256 lAccTokenPerShare = accTokenPerShare;

    if (block.number > lastRewardBlock && totalStaked != 0) {
      uint256 blocks = block.number.sub(lastRewardBlock);
      uint256 reward = blocks.mul(rewardPerBlock).mul(precisionFactor);
      lAccTokenPerShare = lAccTokenPerShare.add(reward.div(totalStaked));
    }
    uint256 _pendingReward = (user.amount.mul(lAccTokenPerShare) / precisionFactor).sub(user.rewardDebt);

    return _pendingReward;
  }

  /// @notice claim an eligible reward
  /// @dev use for external and internal while deposit
  function harvest() external nonReentrant {
    _updatePool();

    UserInfo storage user = userInfo[msg.sender];
    uint256 accumulatedReward = user.amount.mul(accTokenPerShare).div(precisionFactor);
    uint256 _pendingReward = accumulatedReward.sub(user.rewardDebt);
    if (_pendingReward == 0) {
      return;
    }

    require(_isTransferable(_pendingReward), "insufficient reward");
    user.rewardDebt = accumulatedReward;
    rewardToken.safeTransfer(msg.sender, _pendingReward);

    emit Harvest(msg.sender, _pendingReward);
  }

  /// @notice Withdraw staked tokens and collect reward tokens
  function withdraw(uint256 _amount) external nonReentrant {
    UserInfo storage user = userInfo[msg.sender];
    require(user.amount >= _amount, "amount exceeds");

    _updatePool();

    uint256 rewards = user.amount.mul(accTokenPerShare).div(precisionFactor).sub(user.rewardDebt);
    if (rewards > 0) {
      require(_isTransferable(rewards), "insufficient reward");
      rewardToken.safeTransfer(msg.sender, rewards);
    }

    if (_amount > 0) {
      user.amount = user.amount.sub(_amount);
      totalStaked = totalStaked.sub(_amount);

      stakedToken.safeTransfer(msg.sender, _amount);
    }

    user.rewardDebt = user.amount.mul(accTokenPerShare).div(precisionFactor);

    emit Withdraw(msg.sender, _amount);
  }

  /// @notice USE WITH CAUTION - only use when need to get stakedToken without reward
  function emergencyWithdraw() external nonReentrant {
    UserInfo storage user = userInfo[msg.sender];
    uint256 amountToTransfer = user.amount;

    if (amountToTransfer > 0) {
      totalStaked = totalStaked.sub(amountToTransfer);

      stakedToken.safeTransfer(msg.sender, amountToTransfer);
    }

    user.amount = 0;
    user.rewardDebt = 0;

    emit EmergencyWithdraw(msg.sender, amountToTransfer);
  }

  /// @notice Update reward per block
  /// @dev Only callable by owner.
  function setRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
    _updatePool();
    rewardPerBlock = _rewardPerBlock;
    emit SetRewardPerBlock(_rewardPerBlock);
  }

  /// @notice Update reward variables of the given pool to be up-to-date.
  function _updatePool() internal {
    if (block.number <= lastRewardBlock) {
      return;
    }

    if (totalStaked == 0) {
      lastRewardBlock = block.number;
      return;
    }

    uint256 blocks = block.number.sub(lastRewardBlock);
    uint256 rewards = blocks.mul(rewardPerBlock);

    accTokenPerShare = accTokenPerShare.add(rewards.mul(precisionFactor).div(totalStaked));
    lastRewardBlock = block.number;
  }

  function _isTransferable(uint256 _rewards) internal view returns (bool) {
    if (isMultiPool) {
      return _rewards <= rewardToken.balanceOf(address(this));
    }
    return _rewards <= _getActualSingleTokenRewardBalance();
  }

  function _getActualSingleTokenRewardBalance() internal view returns (uint256) {
    return rewardToken.balanceOf(address(this)).sub(totalStaked);
  }
}
