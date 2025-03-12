// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../../lib/solmate/src/utils/SafeTransferLib.sol";
import "../../lib/solmate/src/utils/FixedPointMathLib.sol";
import "./interfaces/IBaseTokenVault.sol";
import "./interfaces/IMigrator.sol";
import "./interfaces/ILp.sol";

abstract contract BaseTokenVault is
  IBaseTokenVault,
  ReentrancyGuard,
  Pausable,
  Ownable
{
  using SafeTransferLib for address;
  using FixedPointMathLib for uint256;
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  /* ========== CONSTANT ========== */
  address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  /* ========== STATE VARIABLES ========== */
  address public rewardsDistribution;
  address public rewardsToken;
  IERC20 public stakingToken;
  uint256 public periodFinish;
  uint256 public rewardRate;
  uint256 public rewardsDuration;
  bool internal isInitialized;

  uint256 public lastUpdateTime;
  uint256 public rewardPerTokenStored;

  mapping(address => uint256) public userRewardPerTokenPaid;
  mapping(address => uint256) public rewards;

  uint256 internal _totalSupply;
  mapping(address => uint256) internal _balances;
  uint256 public ethSupply;

  /* ========== STATE VARIABLES: Migration Options ========== */
  bool public isGovLpVault;
  bool public isMigrated;

  uint256 public reserve;

  IMigrator public migrator;
  address public controller;

  /* ========== EVENTS ========== */
  event RewardAdded(uint256 reward);
  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount, uint256 fee);
  event RewardPaid(address indexed user, uint256 reward);
  event RewardsDurationUpdated(uint256 newDuration);
  event Recovered(address token, uint256 amount);
  event SetRewardDistribution(address newRewardDistribution);

  /* ========== ERRORS ========== */
  error TokenVault_CannotStakeZeroAmount();
  error TokenVault_CannotWithdrawZeroAmount();
  error TokenVault_ProvidedRewardTooHigh();
  error TokenVault_CannotWithdrawStakingToken();
  error TokenVault_RewardPeriodMustBeCompleted();
  error TokenVault_NotRewardsDistributionContract();
  error TokenVault_AlreadyMigrated();
  error TokenVault_NotYetMigrated();
  error TokenVault_NotController();
  error TokenVault_NotOwner();
  error TokenVault_InvalidDuration();
  error TokenVault_AlreadyInitialized();

  /* ========== MODIFIERS ========== */

  modifier updateReward(address account) {
    rewardPerTokenStored = rewardPerToken();
    lastUpdateTime = lastTimeRewardApplicable();
    if (account != address(0)) {
      rewards[account] = earned(account);
      userRewardPerTokenPaid[account] = rewardPerTokenStored;
    }
    _;
  }

  modifier onlyRewardsDistribution() {
    if (msg.sender != rewardsDistribution) {
      revert TokenVault_NotRewardsDistributionContract();
    }
    _;
  }

  modifier whenNotMigrated() {
    if (isMigrated) {
      revert TokenVault_AlreadyMigrated();
    }
    _;
  }

  modifier whenMigrated() {
    if (!isMigrated) {
      revert TokenVault_NotYetMigrated();
    }
    _;
  }

  // since this is more likely to be a clone, this is for checking if msg.sender is an owner of a master contract (a.k.a impl contract)
  modifier onlyMasterContractOwner() {
    if (msg.sender != getMasterContractOwner()) {
      revert TokenVault_NotOwner();
    }
    _;
  }

  /* ========== VIEWS ========== */

  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address _account) external view returns (uint256) {
    return _balances[_account];
  }

  function lastTimeRewardApplicable() public view returns (uint256) {
    return block.timestamp < periodFinish ? block.timestamp : periodFinish;
  }

  function masterContractOwner() external view returns (address) {
    return getMasterContractOwner();
  }

  function rewardPerToken() public view returns (uint256) {
    if (_totalSupply == 0) {
      return rewardPerTokenStored;
    }

    return
      rewardPerTokenStored.add(
        lastTimeRewardApplicable()
          .sub(lastUpdateTime)
          .mul(rewardRate)
          .mul(1e18)
          .div(_totalSupply)
      );
  }

  function earned(address _account) public view returns (uint256) {
    return
      _balances[_account]
        .mul(rewardPerToken().sub(userRewardPerTokenPaid[_account]))
        .div(1e18)
        .add(rewards[_account]);
  }

  function getRewardForDuration() external view returns (uint256) {
    return rewardRate.mul(rewardsDuration);
  }

  /* ========== ADMIN FUNCTIONS ========== */
  function setPaused(bool _paused) external onlyMasterContractOwner {
    // Ensure we're actually changing the state before we do anything
    if (_paused == paused()) {
      return;
    }

    if (_paused) {
      _pause();
      return;
    }

    _unpause();
  }

  function setRewardsDistribution(address _rewardsDistribution)
    external
    onlyMasterContractOwner
  {
    rewardsDistribution = _rewardsDistribution;

    emit SetRewardDistribution(_rewardsDistribution);
  }

  /* ========== MUTATIVE FUNCTIONS ========== */

  function stake(uint256 _amount)
    external
    nonReentrant
    whenNotPaused
    whenNotMigrated
    updateReward(msg.sender)
  {
    if (_amount <= 0) revert TokenVault_CannotStakeZeroAmount();

    _totalSupply = _totalSupply.add(_amount);
    _balances[msg.sender] = _balances[msg.sender].add(_amount);
    stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

    emit Staked(msg.sender, _amount);
  }

  function withdraw(uint256 _amount)
    public
    virtual
    nonReentrant
    whenNotMigrated
    updateReward(msg.sender)
  {
    if (_amount <= 0) revert TokenVault_CannotWithdrawZeroAmount();

    _totalSupply = _totalSupply.sub(_amount);
    _balances[msg.sender] = _balances[msg.sender].sub(_amount);

    stakingToken.safeTransfer(msg.sender, _amount);

    emit Withdrawn(msg.sender, _amount, 0);
  }

  function claimGov() public nonReentrant updateReward(msg.sender) {
    uint256 reward = rewards[msg.sender];
    if (reward > 0) {
      rewards[msg.sender] = 0;
      IERC20(rewardsToken).safeTransfer(msg.sender, reward);
      emit RewardPaid(msg.sender, reward);
    }
  }

  function exit() external {
    withdraw(_balances[msg.sender]);
    claimGov();
  }

  /* ========== RESTRICTED FUNCTIONS ========== */

  function notifyRewardAmount(uint256 _reward)
    external
    virtual
    onlyRewardsDistribution
    updateReward(address(0))
  {
    if (block.timestamp >= periodFinish) {
      rewardRate = _reward.div(rewardsDuration);
    } else {
      uint256 remaining = periodFinish.sub(block.timestamp);
      uint256 leftover = remaining.mul(rewardRate);
      rewardRate = _reward.add(leftover).div(rewardsDuration);
    }

    // Ensure the provided reward amount is not more than the balance in the contract.
    // This keeps the reward rate in the right range, preventing overflows due to
    // very high values of rewardRate in the earned and rewardsPerToken functions;
    // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
    uint256 balance = IERC20(rewardsToken).balanceOf(address(this));
    if (rewardRate > balance.div(rewardsDuration))
      revert TokenVault_ProvidedRewardTooHigh();

    lastUpdateTime = block.timestamp;
    periodFinish = block.timestamp.add(rewardsDuration);
    emit RewardAdded(_reward);
  }

  // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
  function recoverERC20(address _tokenAddress, uint256 _tokenAmount)
    external
    onlyMasterContractOwner
  {
    if (_tokenAddress == address(stakingToken))
      revert TokenVault_CannotWithdrawStakingToken();

    IERC20(_tokenAddress).safeTransfer(owner(), _tokenAmount);

    emit Recovered(_tokenAddress, _tokenAmount);
  }

  function setRewardsDuration(uint256 _rewardsDuration)
    external
    onlyMasterContractOwner
  {
    if (block.timestamp <= periodFinish) {
      revert TokenVault_RewardPeriodMustBeCompleted();
    }

    if (_rewardsDuration < 1 days || _rewardsDuration > 30 days) {
      // Acceptable duration is between 1 - 10 days
      revert TokenVault_InvalidDuration();
    }

    rewardsDuration = _rewardsDuration;

    emit RewardsDurationUpdated(rewardsDuration);
  }

  function getMasterContractOwner() public view virtual returns (address) {}

  /// @dev Fallback function to accept ETH.
  receive() external payable {}
}
