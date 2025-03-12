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
  uint256 public immutable startBlock;
  uint256 public immutable endBlock;
  uint256 public immutable claimableBlock;
  bool public immutable isLockWithdraw;
  ERC20 public immutable stakedToken;
  ERC20 public immutable rewardToken;

  /// @dev define fixed APR percentage and reward ratio from constructor
  uint256 public immutable apr;
  uint256 public immutable cap;
  uint256 public immutable tokenRatio;
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

  constructor(
    ERC20 _stakedToken,
    ERC20 _rewardToken,
    uint256 _cap,
    uint256 _apr,
    uint256 _tokenRatio,
    uint256 _startBlock,
    uint256 _endBlock,
    bool _isLockWithdraw,
    address _admin
  ) {
    stakedToken = _stakedToken;
    rewardToken = _rewardToken;
    cap = _cap;
    apr = _apr;
    tokenRatio = _tokenRatio;
    startBlock = _startBlock;
    endBlock = _endBlock;
    isLockWithdraw = _isLockWithdraw;
    claimableBlock = _startBlock;
    actualTokenRatio = _tokenRatio;

    if (_rewardToken.decimals() > _stakedToken.decimals()) {
      actualTokenRatio = _tokenRatio.mul(10**(_rewardToken.decimals() - _stakedToken.decimals()));
    }

    if (_rewardToken.decimals() < _stakedToken.decimals()) {
      actualTokenRatio = _tokenRatio.div(10**(_stakedToken.decimals() - _rewardToken.decimals()));
    }

    rewardPerBlock = _apr.mul(actualTokenRatio).div(BLOCK_PER_DAY.mul(DAY_PER_YEAR));
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
    rewardDebt = rewardDebt.add(_calculateReward(_actualAmount, endBlock.sub(_lastRewardBlock())));

    if (stakedToken == rewardToken) {
      require(rewardDebt <= rewardToken.balanceOf(address(this)).sub(totalStaked), "insufficient reward reserve");
    } else {
      require(rewardDebt <= rewardToken.balanceOf(address(this)), "insufficient reward reserve");
    }

    UserInfo storage user = userInfo[msg.sender];
    user.amount = user.amount.add(_actualAmount);
    user.lastRewardBlock = _lastRewardBlock();

    emit Deposit(msg.sender, _actualAmount);
  }

  function pendingReward(address _for) external view returns (uint256) {
    require(_for != address(0), "bad address");
    UserInfo storage user = userInfo[_for];
    return calculateReward(user.amount, user.lastRewardBlock);
  }

  function harvest() public {
    UserInfo storage user = userInfo[msg.sender];
    if (user.amount > 0 && block.number > claimableBlock) {
      uint256 _reward = calculateReward(user.amount, user.lastRewardBlock);
      rewardToken.safeTransfer(msg.sender, _reward);
      rewardDebt = rewardDebt.sub(_reward);
      emit Harvest(msg.sender, _reward);
    }
    user.lastRewardBlock = block.number;
  }

  function withdraw(uint256 _withdrawAmount) external nonReentrant {
    if (isLockWithdraw) {
      require(block.number > endBlock, "not allow before end period");
    }

    UserInfo storage user = userInfo[msg.sender];
    if (user.amount > 0) {
      harvest();

      stakedToken.safeTransfer(msg.sender, _withdrawAmount);

      if (endBlock >= block.number) {
        uint256 _reward = calculateReward(_withdrawAmount, user.lastRewardBlock);
        uint256 blockLeft = endBlock.sub(block.number);
        uint256 amountLeft = user.amount.sub(_withdrawAmount);

        rewardDebt = rewardDebt.add(_reward).sub(_calculateReward(user.amount.sub(amountLeft), blockLeft));
      }

      user.amount = user.amount.sub(_withdrawAmount);
      user.lastRewardBlock = _lastRewardBlock();
      totalStaked = totalStaked.sub(_withdrawAmount);

      emit Withdraw(msg.sender, _withdrawAmount);
    }
  }

  function recoveryReward(address _for) external onlyOwner {
    require(block.number > endBlock, "not allow before end period");

    uint256 rewardBalance;
    if (stakedToken == rewardToken) {
      rewardBalance = rewardToken.balanceOf(address(this)).sub(totalStaked);
    } else {
      rewardBalance = rewardToken.balanceOf(address(this));
    }

    uint256 transferAmount = rewardBalance.sub(rewardDebt);
    rewardToken.safeTransfer(_for, transferAmount);
    emit RecoveryReward(_for, transferAmount);
  }

  function calculateReward(uint256 _amount, uint256 _calculateFromBlock) internal view returns (uint256) {
    uint256 toBlock = block.number;
    if (toBlock <= _calculateFromBlock || endBlock <= _calculateFromBlock) {
      return 0;
    }
    if (toBlock > endBlock) {
      toBlock = endBlock;
    }

    uint256 blocks = toBlock.sub(_calculateFromBlock);
    return _calculateReward(_amount, blocks);
  }

  function _calculateReward(uint256 _amount, uint256 _blocks) internal view returns (uint256) {
    return _amount.mul(_blocks.mul(rewardPerBlock)).div(rewardPerBlockPrecisionFactor);
  }

  function _lastRewardBlock() internal view returns (uint256) {
    if (block.number > claimableBlock) {
      return block.number;
    }
    return claimableBlock;
  }
}
