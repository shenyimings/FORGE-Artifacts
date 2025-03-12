//contracts/EarnOtherFixedAPR.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract EarnOtherFixedAPR is Ownable, ReentrancyGuard {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  /// @dev define from constructor 
  uint256 private constant BLOCK_PER_DAY = 28800;
  uint256 private constant DAY_PER_YEAR = 365;
  uint256 private constant RATIO_PRECISION = 1e18;
  uint256 private constant PERCENTAGE_PRECISION = 1e2;
  uint256 private constant APR_PRECISION = 1e18;

  /// @dev define from constructor 
  uint256 public startBlock;
  uint256 public endBlock;
  uint256 public claimableBlock;
  ERC20 public stakedToken;
  ERC20 public rewardToken;

  /// @dev define fixed APR percentage and reward ratio from constructor
  uint256 public apr;
  uint256 public cap;
  uint256 public tokenRatio;
  uint256 private rewardPerBlockPrecisionFactor;
  uint256 private actualTokenRatio;
  uint256 private rewardPerBlock;

  /// @dev Pool debt total staked from all users
  uint256 public totalStaked;
  uint256 public rewardDebt;

  /// @dev Info of each user that stakes tokens (stakedToken)
  mapping(address => UserInfo) public userInfo;

  struct UserInfo {
    uint256 amount;
    uint256 lastRewardBlock;
  }

  event Deposit(address indexed user, uint256 amount);
  event Withdraw(address indexed user, uint256 amount);
  event Harvest(address indexed user, uint256 amount);
  event RecoveryReward(address indexed user, uint256 amount);
  event EmergencyWithdraw(address indexed user, uint256 amount);

  constructor(
    ERC20 _stakedToken,
    ERC20 _rewardToken,
    uint256 _cap,
    uint256 _apr,
    uint256 _tokenRatio,
    uint256 _startBlock,
    uint256 _endBlock,
    address _admin
  ) {
    stakedToken = _stakedToken;
    rewardToken = _rewardToken;
    cap = _cap;
    apr = _apr;
    tokenRatio = _tokenRatio;
    startBlock = _startBlock;
    endBlock = _endBlock;
    claimableBlock = _startBlock;
    actualTokenRatio = _tokenRatio;

    if (_rewardToken.decimals() > _stakedToken.decimals()) {
      actualTokenRatio = _tokenRatio.mul(10**(_rewardToken.decimals() - _stakedToken.decimals()));
    }

    if (_rewardToken.decimals() < _stakedToken.decimals()) {
      actualTokenRatio = _tokenRatio.div(10**(_stakedToken.decimals() - _rewardToken.decimals()));
    }

    rewardPerBlock = apr.div(BLOCK_PER_DAY.mul(DAY_PER_YEAR)).mul(actualTokenRatio);
    rewardPerBlockPrecisionFactor = RATIO_PRECISION.mul(PERCENTAGE_PRECISION).mul(APR_PRECISION);

    transferOwnership(_admin);
  }

  function deposit(uint256 _amount) external nonReentrant {
    require(block.number >= startBlock, "not allow before start period");
    require(block.number < endBlock, "not allow after end period");
    require(totalStaked < cap, "pool capacity is reached");

    harvest();

    uint256 _remaining = cap.sub(totalStaked);
    uint256 _preDeposit = stakedToken.balanceOf(address(this));

    if (_remaining < _amount) {
      stakedToken.safeTransferFrom(msg.sender, address(this), _remaining);
    } else {
      stakedToken.safeTransferFrom(msg.sender, address(this), _amount);
    }

    uint256 _postDeposit = stakedToken.balanceOf(address(this));
    uint256 _actualAmount = _postDeposit.sub(_preDeposit);
    totalStaked = totalStaked.add(_actualAmount);
    rewardDebt = rewardDebt.add(
      _actualAmount.mul((endBlock.sub(_lastRewardBlock())).mul(rewardPerBlock)).div(rewardPerBlockPrecisionFactor)
    );

    UserInfo storage user = userInfo[msg.sender];
    user.amount = user.amount.add(_actualAmount);
    user.lastRewardBlock = _lastRewardBlock();

    emit Deposit(msg.sender, _actualAmount);
  }

  function pendingReward(address _for) external view returns (uint256) {
    require(_for != address(0), "bad address");
    UserInfo storage user = userInfo[_for];
    return _calculateReward(user.amount, user.lastRewardBlock);
  }

  function harvest() public {
    UserInfo storage user = userInfo[msg.sender];
    if (user.amount > 0 && block.number > claimableBlock) {
      uint256 _reward = _calculateReward(user.amount, user.lastRewardBlock);
      require(_reward <= rewardToken.balanceOf(address(this)), "insufficeint reward");
      rewardToken.safeTransfer(msg.sender, _reward);
      rewardDebt = rewardDebt.sub(_reward);
      emit Harvest(msg.sender, _reward);
    }
    user.lastRewardBlock = block.number;
  }

  function withdraw() external nonReentrant {
    require(block.number > endBlock, "not allow before end period");

    UserInfo storage user = userInfo[msg.sender];
    if (user.amount > 0) {
      harvest();

      uint256 _withdrawAmount = user.amount;
      stakedToken.safeTransfer(msg.sender, _withdrawAmount);

      user.amount = 0;
      user.lastRewardBlock = _lastRewardBlock();
      totalStaked = totalStaked.sub(_withdrawAmount);

      emit Withdraw(msg.sender, _withdrawAmount);
    }
  }

  /// @notice while LP is locked, but reward is insufficient user have right to emergency withdraw thier LP
  /// @notice all the rewards of actor will be cancelled and not be able to claim in the future
  function emergencyWithdraw() external nonReentrant {
    UserInfo storage user = userInfo[msg.sender];
    uint256 rewards = _calculateReward(user.amount, user.lastRewardBlock);

    if (block.number < endBlock) {
      require(
        rewards > rewardToken.balanceOf(address(this)),
        "not allow before end period"
      );
      rewards = user.amount.mul((endBlock.sub(user.lastRewardBlock)).mul(rewardPerBlock)).div(
        rewardPerBlockPrecisionFactor
      );
    }

    uint256 withdrawAmount = user.amount;
    stakedToken.safeTransfer(msg.sender, withdrawAmount);

    user.amount = 0;
    user.lastRewardBlock = endBlock;

    totalStaked = totalStaked.sub(withdrawAmount);
    rewardDebt = rewardDebt.sub(rewards);

    emit EmergencyWithdraw(msg.sender, withdrawAmount);
  }

  function recoveryReward(address _for) external onlyOwner {
    require(block.number > endBlock, "not allow before end period");

    uint256 unusedReward = rewardToken.balanceOf(address(this)).sub(rewardDebt);
    rewardToken.safeTransfer(_for, unusedReward);
    emit RecoveryReward(_for, unusedReward);
  }

  function _calculateReward(uint256 _amount, uint256 _calculateFromBlock) internal view returns (uint256) {
    uint256 toBlock = block.number;
    if (toBlock <= _calculateFromBlock) {
      return 0;
    }
    if (toBlock > endBlock) {
      toBlock = endBlock;
    }

    uint256 blocks = toBlock.sub(_calculateFromBlock);
    return _amount.mul(blocks.mul(rewardPerBlock)).div(rewardPerBlockPrecisionFactor);
  }

  function _lastRewardBlock() internal view returns (uint256) {
    if (block.number > claimableBlock) {
      return block.number;
    }
    return claimableBlock;
  }
}
