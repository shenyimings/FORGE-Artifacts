//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import './IRewardToken.sol';

contract StakingContract is Ownable, ReentrancyGuard {
  using SafeMath for uint256;

  // Token given as reward for staking
  IRewardToken public immutable rewardToken;
  // Token deposited for staking
  IERC20 public immutable stakedToken;

  // Total staked token balance
  uint256 public totalStakedSupply;
  // Staked LP token balance of each user
  mapping(address => uint256) public stakedBalances;
  // First deposit timestamp of each user
  mapping(address => uint256) public firstDepositTimestamps;
  // Used for calculating the latest rewards. Resets after each reward claim.
  mapping(address => uint256) public rewardCalculationStartTimestamps;
  // The pending rewards, saved each time user tops up staked balance
  mapping(address => uint256) public pendingRewardsUpToLastDeposit;

  // Yearly mint rate per staked token
  uint256 public immutable APRM;
  // Basis points of staked token processing fee taken when user withdraws
  uint256 public immutable processingFeeForStakedToken;

  // Minimum number of tokens that can be staked
  uint256 public minimumStakeAmount;
  // Minimum stake time to receive rewards after the first deposit
  uint256 public minimumStakeTime;
  // Address of fee vault
  address public feeVaultAddress;

  bool public depositsPaused;
  bool public withdrawalsPaused;

  event Deposit(address indexed account, uint256 indexed amount);
  event Withdrawal(address indexed account, uint256 indexed amount);
  event EmergencyWithdrawal(address indexed account, uint256 indexed amount);
  event RewardClaim(address indexed account, uint256 indexed amount);
  event DepositsPaused(bool indexed paused);
  event WithdrawalsPaused(bool indexed paused);

  constructor(
    address _rewardToken,
    address _stakedToken,
    uint256 _APRM,
    uint256 _minimumStakeAmount,
    uint256 _minimumStakeTime,
    uint256 _processingFeeForStakedToken,
    address _feeVaultAddress
  ) {
    rewardToken = IRewardToken(_rewardToken);
    stakedToken = IERC20(_stakedToken);
    APRM = _APRM;
    minimumStakeAmount = _minimumStakeAmount;
    minimumStakeTime = _minimumStakeTime;
    processingFeeForStakedToken = _processingFeeForStakedToken;
    feeVaultAddress = _feeVaultAddress;
    depositsPaused = false;
    withdrawalsPaused = false;
  }

  /**
   * @dev Throws if deposit is paused.
   */
  modifier whenDepositNotPaused() {
    require(!depositsPaused, 'DEPOSITS ARE PAUSED');
    _;
  }

  /**
   * @dev Throws if withdraw is paused.
   */
  modifier whenWithdrawNotPaused() {
    require(!withdrawalsPaused, 'WITHDRAWS ARE PAUSED');
    _;
  }

  /**
   * Allows user to deposit the token for staking and earn reward token, calculated with the APRM.
   * To be able to deposit user should give allowance to the staking contract and
   * deposit at least the minimum stake amount.
   */
  function deposit(uint256 amount) external nonReentrant whenDepositNotPaused {
    require(amount <= stakedToken.allowance(msg.sender, address(this)), 'NOT ENOUGH ALLOWANCE');
    require(amount <= stakedToken.balanceOf(msg.sender), 'NOT ENOUGH TOKEN BALANCE');
    require(amount >= minimumStakeAmount, 'AMOUNT CANNOT BE SMALLER THAN MINIMUM AMOUNT');

    uint256 balanceOfAccount = stakedBalances[msg.sender];

    if (balanceOfAccount > 0) {
      // Adds all pending rewards to pending rewards of the account.
      pendingRewardsUpToLastDeposit[msg.sender] = calculateTotalPendingRewards(msg.sender);
    }

    // Adds amount to total supply and balance of the account, sets timestamps of the account.
    totalStakedSupply = totalStakedSupply.add(amount);
    stakedBalances[msg.sender] = stakedBalances[msg.sender].add(amount);
    if (firstDepositTimestamps[msg.sender] == 0) {
      firstDepositTimestamps[msg.sender] = block.timestamp;
    }
    rewardCalculationStartTimestamps[msg.sender] = block.timestamp;

    // Receives tokens from the account.
    bool success = stakedToken.transferFrom(msg.sender, address(this), amount);
    require(success, 'TRANSFER_FROM REVERTED');

    emit Deposit(msg.sender, amount);
  }

  /**
   * Claim pending rewards if minimum stake time has passed since the first deposit.
   */
  function claimRewards() external nonReentrant whenWithdrawNotPaused {
    uint256 userBalance = stakedBalances[msg.sender];
    require(userBalance > 0, 'NO STAKED BALANCE');
    require(
      (block.timestamp - firstDepositTimestamps[msg.sender]) >= minimumStakeTime,
      'MINIMUM STAKE TIME HAS NOT PASSED'
    );

    uint256 totalRewardsAmount = calculateTotalPendingRewards(msg.sender);
    require(totalRewardsAmount > 0, 'NO PENDING REWARDS');

    rewardCalculationStartTimestamps[msg.sender] = block.timestamp;
    pendingRewardsUpToLastDeposit[msg.sender] = 0;

    // Mints total rewards amount for the user and fee vault.
    rewardToken.mint(msg.sender, totalRewardsAmount);
    rewardToken.mint(feeVaultAddress, totalRewardsAmount);
    emit RewardClaim(msg.sender, totalRewardsAmount);
  }

  /**
   * Withdraws all tokens of an account and rewards.
   */
  function withdraw() external nonReentrant whenWithdrawNotPaused {
    uint256 userBalance = stakedBalances[msg.sender];
    require(userBalance > 0, 'NO STAKED BALANCE');

    // Calculate total rewards amount (if minimumStakeTime has passed), and reset timestamp and pending rewards of the account
    uint256 totalRewardsAmount;
    if (block.timestamp - firstDepositTimestamps[msg.sender] >= minimumStakeTime) {
      totalRewardsAmount = calculateTotalPendingRewards(msg.sender);
    }
    rewardCalculationStartTimestamps[msg.sender] = 0;
    pendingRewardsUpToLastDeposit[msg.sender] = 0;
    firstDepositTimestamps[msg.sender] = 0;

    // Substract amount from total supply and reset balance of the account.
    totalStakedSupply = totalStakedSupply.sub(userBalance);
    stakedBalances[msg.sender] = 0;

    // Send staked tokens to the user account and fees to feeVault.
    uint256 stakeTokenFee = userBalance.mul(processingFeeForStakedToken).div(10000);
    uint256 stakeTokenAmountAfterFee = userBalance.sub(stakeTokenFee);
    bool transferToSender = stakedToken.transfer(msg.sender, stakeTokenAmountAfterFee);
    bool transferToVault = stakedToken.transfer(feeVaultAddress, stakeTokenFee);
    require(transferToSender && transferToVault, 'TRANSFER REVERTED');
    emit Withdrawal(msg.sender, stakeTokenAmountAfterFee);

    if (totalRewardsAmount > 0) {
      // Mints total rewards amount for the user and fee vault.
      rewardToken.mint(msg.sender, totalRewardsAmount);
      rewardToken.mint(feeVaultAddress, totalRewardsAmount);
      emit RewardClaim(msg.sender, totalRewardsAmount);
    }
  }

  /**
   * Withdraws all tokens of an account immediately without a reward.
   */
  function emergencyWithdraw() external nonReentrant {
    uint256 userBalance = stakedBalances[msg.sender];
    require(userBalance > 0, 'NO STAKED BALANCE');

    // Substract amount from total supply and resets all data of the account.
    totalStakedSupply = totalStakedSupply.sub(userBalance);
    stakedBalances[msg.sender] = 0;
    firstDepositTimestamps[msg.sender] = 0;
    rewardCalculationStartTimestamps[msg.sender] = 0;
    pendingRewardsUpToLastDeposit[msg.sender] = 0;

    // Sends tokens to the account and fees to vault.
    uint256 stakeTokenFee = userBalance.mul(processingFeeForStakedToken).div(10000);
    uint256 stakeTokenAmountAfterFee = userBalance.sub(stakeTokenFee);
    bool transferToSender = stakedToken.transfer(msg.sender, stakeTokenAmountAfterFee);
    bool transferToVault = stakedToken.transfer(feeVaultAddress, stakeTokenFee);
    require(transferToSender && transferToVault, 'TRANSFER REVERTED');
    emit EmergencyWithdrawal(msg.sender, stakeTokenAmountAfterFee);
  }

  /**
   * Calculate rewards.
   */
  function calculateLatestRewards(address userAddress) public view returns (uint256) {
    // Subtract current time from starting time and convert the timestamp to the day.
    uint256 dayCount = (block.timestamp - rewardCalculationStartTimestamps[userAddress]).div(60).div(60).div(24);
    // Calculate yearly mint rate.
    uint256 yearlyMint = stakedBalances[userAddress].mul(APRM).div(10000);
    // Calculate total amount of interest.
    uint256 rewards = yearlyMint.div(365).mul(dayCount);

    return rewards;
  }

  /**
   * Return total pending rewards.
   */
  function calculateTotalPendingRewards(address userAddress) public view returns (uint256) {
    uint256 pendingSinceLastDeposit = calculateLatestRewards(userAddress);
    return pendingSinceLastDeposit.add(pendingRewardsUpToLastDeposit[userAddress]);
  }

  /**
   * Set Minimum Stake Amount.
   */
  function setMinimumStakeAmount(uint256 _minimumStakeAmount) public onlyOwner {
    minimumStakeAmount = _minimumStakeAmount;
  }

  /**
   * Set Minimum Stake Time.
   */
  function setMinimumStakeTime(uint256 _minimumStakeTime) public onlyOwner {
    minimumStakeTime = _minimumStakeTime;
  }

  /**
   * Set Processing Fee Vault Address.
   */
  function setFeeVaultAddress(address _address) public onlyOwner {
    feeVaultAddress = _address;
  }

  /**
   * Pause/unpause deposits.
   */
  function pauseDeposits(bool pause) public onlyOwner {
    depositsPaused = pause;
    emit DepositsPaused(pause);
  }

  /**
   * Pause/unpause withdrawals.
   */
  function pauseWithdrawals(bool pause) public onlyOwner {
    withdrawalsPaused = pause;
    emit WithdrawalsPaused(pause);
  }
}
