// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IPool } from "../interfaces/IPool.sol";
import { IStaking } from "../staking/interfaces/IStaking.sol";
import { IRewarder } from "../staking/interfaces/IRewarder.sol";
import { LockdropConfig } from "./LockdropConfig.sol";
import { ILockdrop } from "./interfaces/ILockdrop.sol";
import { P88 } from "../tokens/P88.sol";
import { PoolRouter } from "../core/pool-diamond/PoolRouter.sol";
import { IWNative } from "../interfaces/IWNative.sol";

contract Lockdrop is ReentrancyGuardUpgradeable, OwnableUpgradeable {
  // --- Libraries ---
  using SafeERC20Upgradeable for IERC20Upgradeable;

  // --- Events ---
  event LogLockToken(address indexed user, uint256 amount, uint256 lockPeriod);
  event LogAddLockAmount(address indexed user, uint256 amount);
  event LogExtendLockPeriod(address indexed user, uint256 lockPeriod);
  event LogWithdrawLockToken(
    address indexed user,
    address token,
    uint256 amount,
    uint256 remainingAmount
  );
  event LogWithdrawAll(address indexed user, address token);
  event LogAllocateP88(uint256 amount);
  event LogClaimAllP88(address indexed user, uint256 p88Amount);
  event LogClaimReward(address indexed user, address token, uint256 amount);
  event LogStakePLP(uint256 plpTokenAmount);

  // --- Custom Errors ---
  error Lockdrop_ZeroAmountNotAllowed();
  error Lockdrop_ZeroP88WeightNotAllowed();
  error Lockdrop_InvalidStartLockTimestamp();
  error Lockdrop_InvalidLockPeriod();
  error Lockdrop_InvalidWithdrawAllPeriod();
  error Lockdrop_NotInLockdropPeriod();
  error Lockdrop_InsufficientBalance();
  error Lockdrop_NotPassLockdropPeriod();
  error Lockdrop_P88AlreadyClaimed();
  error Lockdrop_NoPosition();
  error Lockdrop_InvalidAmount();
  error Lockdrop_UserAlreadyLocked();
  error Lockdrop_ZeroTotalPLPAmount();
  error Lockdrop_NotAllocationFeeder();
  error Lockdrop_ZeroTotalP88NotAllowed();
  error Lockdrop_AlreadyAllocateP88();
  error Lockdrop_PLPAlreadyStaked();
  error Lockdrop_NotGateway();
  error Lockdrop_PLPNotYetStake();
  error Lockdrop_WithdrawNotAllowed();
  error Lockdrop_NotLockdropCompounder();

  // --- Structs ---
  struct LockdropState {
    uint256 lockdropTokenAmount;
    uint256 lockPeriod;
    uint256[] userRewardDebts;
    bool p88Claimed;
    bool restrictedWithdrawn; // true if user withdraw already (use in the last day)
  }

  // --- States ---
  IERC20Upgradeable public lockdropToken; // lockdrop token address
  LockdropConfig public lockdropConfig;
  address public pool;
  PoolRouter public poolRouter;
  uint256 public totalAmount; // total amount of token
  uint256 public totalP88Weight; // Sum of amount * lockPeriod
  uint256 public totalP88;
  uint256 public totalPLPAmount;
  address[] public rewardTokens; //The index of each reward token will remain the same, for example, 0 for MATIC and 1 for esP88
  uint256[] public accRewardPerShares; // Accum reward per share
  address public nativeTokenAddress;

  mapping(address => LockdropState) public lockdropStates;

  // --- Modifiers ---
  /// @dev Only in lockdrop period
  modifier onlyInLockdropPeriod() {
    if (
      block.timestamp < lockdropConfig.startLockTimestamp() ||
      block.timestamp > lockdropConfig.endLockTimestamp()
    ) revert Lockdrop_NotInLockdropPeriod();
    _;
  }

  /// @dev Only able to procees after lockdrop period
  modifier onlyAfterLockdropPeriod() {
    if (block.timestamp < lockdropConfig.endLockTimestamp())
      revert Lockdrop_NotPassLockdropPeriod();
    _;
  }

  /// @dev ACL Gateway
  modifier onlyGateway() {
    if (msg.sender != lockdropConfig.gatewayAddress())
      revert Lockdrop_NotGateway();
    _;
  }

  /// @dev ACL Lockdrop Compounder
  modifier onlyLockdropCompounder() {
    if (msg.sender != lockdropConfig.lockdropCompounderAddress())
      revert Lockdrop_NotLockdropCompounder();
    _;
  }

  function initialize(
    address lockdropToken_,
    address pool_,
    address payable poolRouter_,
    LockdropConfig lockdropConfig_,
    address[] memory rewardTokens_,
    address nativeTokenAddress_
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    // Sanity check
    IERC20Upgradeable(lockdropToken_).balanceOf(address(this));
    if (block.timestamp > lockdropConfig_.startLockTimestamp())
      revert Lockdrop_InvalidStartLockTimestamp();

    lockdropToken = IERC20Upgradeable(lockdropToken_);
    lockdropConfig = lockdropConfig_;
    rewardTokens = rewardTokens_;
    pool = pool_;
    poolRouter = PoolRouter(poolRouter_);
    nativeTokenAddress = nativeTokenAddress_;
    accRewardPerShares = new uint256[](rewardTokens.length);
  }

  function _lockTokenFor(
    uint256 amount,
    uint256 lockPeriod,
    address user
  ) internal {
    if (lockdropStates[user].lockdropTokenAmount > 0)
      revert Lockdrop_UserAlreadyLocked();
    if (amount == 0) revert Lockdrop_ZeroAmountNotAllowed();
    if (lockPeriod < (7 days) || lockPeriod > (7 days * 52))
      revert Lockdrop_InvalidLockPeriod(); // Less than 7 days or more than 364 days

    uint256[] memory userAccRewardPerShares = new uint256[](
      rewardTokens.length
    );
    uint256[] memory userRewardDebts = new uint256[](rewardTokens.length);

    lockdropStates[user] = LockdropState({
      lockdropTokenAmount: amount,
      lockPeriod: lockPeriod,
      userRewardDebts: userRewardDebts,
      p88Claimed: false,
      restrictedWithdrawn: false
    });

    accRewardPerShares = userAccRewardPerShares;
    totalAmount += amount;
    totalP88Weight += amount * lockPeriod;
    lockdropToken.safeTransferFrom(msg.sender, address(this), amount);
    emit LogLockToken(user, amount, lockPeriod);
  }

  /// @dev Users can lock their ERC20 Token during the lockdrop period
  /// @param amount Number of token that user wants to lock
  /// @param lockPeriod Number of second that user wants to lock
  function lockToken(uint256 amount, uint256 lockPeriod)
    external
    onlyInLockdropPeriod
    nonReentrant
  {
    _lockTokenFor(amount, lockPeriod, msg.sender);
  }

  /// @dev Users can lock their ERC20 Token during the lockdrop period
  /// @param amount Number of token that user wants to lock
  /// @param lockPeriod Number of second that user wants to lock
  /// @param user Address of the user that wants to lock the token
  function lockTokenFor(
    uint256 amount,
    uint256 lockPeriod,
    address user
  ) external onlyInLockdropPeriod onlyGateway {
    _lockTokenFor(amount, lockPeriod, user);
  }

  function _extendLockPeriodFor(uint256 newLockPeriod, address user) internal {
    if (newLockPeriod > (7 days * 52)) revert Lockdrop_InvalidLockPeriod(); // New lock period should not be more than 364 days
    if (lockdropStates[user].lockdropTokenAmount == 0)
      revert Lockdrop_NoPosition();
    if (newLockPeriod < lockdropStates[user].lockPeriod)
      revert Lockdrop_InvalidLockPeriod();
    totalP88Weight +=
      lockdropStates[user].lockdropTokenAmount *
      (newLockPeriod - lockdropStates[user].lockPeriod);
    lockdropStates[user].lockPeriod = newLockPeriod;
    emit LogExtendLockPeriod(user, newLockPeriod);
  }

  /// @dev Users can extend their lock period during the lockdrop period
  /// @param newLockPeriod New number of second that user wants to lock
  function extendLockPeriod(uint256 newLockPeriod)
    external
    onlyInLockdropPeriod
    nonReentrant
  {
    _extendLockPeriodFor(newLockPeriod, msg.sender);
  }

  /// @dev Users can extend their lock period during the lockdrop period
  /// @param newLockPeriod New number of second that user wants to lock
  /// @param user Address of the user that wants extend the lock period
  function extendLockPeriodFor(uint256 newLockPeriod, address user)
    external
    onlyInLockdropPeriod
    onlyGateway
    nonReentrant
  {
    _extendLockPeriodFor(newLockPeriod, user);
  }

  function _addLockAmountFor(uint256 amount, address user) internal {
    if (amount == 0) revert Lockdrop_ZeroAmountNotAllowed();
    if (lockdropStates[user].lockdropTokenAmount == 0)
      revert Lockdrop_NoPosition();
    lockdropStates[user].lockdropTokenAmount += amount;
    totalAmount += amount;
    totalP88Weight += amount * lockdropStates[user].lockPeriod;
    // Gateway call the function
    lockdropToken.safeTransferFrom(msg.sender, address(this), amount);
    emit LogAddLockAmount(user, amount);
  }

  /// @dev Users can add more lock amount during the lockdrop period
  /// @param amount Number of lock token that user wants to add
  function addLockAmount(uint256 amount) external onlyInLockdropPeriod {
    _addLockAmountFor(amount, msg.sender);
  }

  /// @dev Users can add more lock amount during the lockdrop period
  /// @param amount Number of lock token that user wants to add
  function addLockAmountFor(uint256 amount, address user)
    external
    onlyInLockdropPeriod
    onlyGateway
    nonReentrant
  {
    _addLockAmountFor(amount, user);
  }

  function _getEarlyWithdrawableAmount(address user)
    internal
    view
    returns (uint256 amount)
  {
    uint256 startRestrictedWithdrawalTimestamp = lockdropConfig
      .startRestrictedWithdrawalTimestamp();
    uint256 lockdropTokenAmount = lockdropStates[user].lockdropTokenAmount;
    uint256 decayPercentage = lockdropConfig.decayStartPercentage();
    if (block.timestamp < startRestrictedWithdrawalTimestamp)
      return lockdropTokenAmount;
    if (block.timestamp >= startRestrictedWithdrawalTimestamp) {
      if (
        block.timestamp >= lockdropConfig.startDecayingWithdrawalTimestamp()
      ) {
        return
          (((decayPercentage *
            (lockdropConfig.endLockTimestamp() - block.timestamp)) /
            lockdropConfig.startTimeDecay()) * lockdropTokenAmount) / 100;
      }
      return ((lockdropTokenAmount * decayPercentage) / 100);
    }
  }

  /// @dev Withdrawable amount calculation logic
  /// @param user Address of user that we want to know their valid withdraw amount
  function getEarlyWithdrawableAmount(address user)
    external
    view
    returns (uint256)
  {
    return _getEarlyWithdrawableAmount(user);
  }

  /// @dev Users able to withdraw their ERC20 Token within lockdrop period
  /// @param amount Number of token that user wants to withdraw
  /// @param user Address of the user that wants to withdraw
  function earlyWithdrawLockedToken(uint256 amount, address user)
    external
    payable
    onlyInLockdropPeriod
    nonReentrant
  {
    uint256 lockdropTokenAmount = lockdropStates[user].lockdropTokenAmount;
    if (lockdropStates[user].restrictedWithdrawn)
      revert Lockdrop_WithdrawNotAllowed();
    if (amount == 0) revert Lockdrop_ZeroAmountNotAllowed();
    if (amount > lockdropTokenAmount) revert Lockdrop_InsufficientBalance();
    if (amount > _getEarlyWithdrawableAmount(user))
      revert Lockdrop_InvalidAmount();

    lockdropStates[user].lockdropTokenAmount -= amount;
    totalAmount -= amount;
    totalP88Weight -= amount * lockdropStates[user].lockPeriod;
    if (lockdropStates[user].lockdropTokenAmount == 0) {
      delete lockdropStates[user];
    }
    if (
      block.timestamp >= lockdropConfig.startRestrictedWithdrawalTimestamp()
    ) {
      lockdropStates[user].restrictedWithdrawn = true;
    }

    if (address(lockdropToken) != nativeTokenAddress) {
      lockdropToken.safeTransfer(msg.sender, amount);
    } else {
      IWNative(nativeTokenAddress).withdraw(amount);
      payable(msg.sender).transfer(amount);
    }

    emit LogWithdrawLockToken(
      user,
      address(lockdropToken),
      amount,
      lockdropStates[user].lockdropTokenAmount
    );
  }

  /// @dev Users able to withdraw all their PLP Token after the end of the lockdrop period + their input lock period
  /// @param user Address of the user that wants to withdraw
  /// Withdraw Tokens
  // -> MATIC
  // -> EsP88
  // -> PLP
  function withdrawAll(address user) external nonReentrant onlyGateway {
    if (totalPLPAmount == 0) revert Lockdrop_ZeroTotalPLPAmount();
    if (
      block.timestamp <
      lockdropStates[user].lockPeriod + lockdropConfig.endLockTimestamp()
    ) revert Lockdrop_InvalidWithdrawAllPeriod();

    // Claim All Reward for user at the same time.
    // User will receive EsP88 and Revenue Native(MATIC) Tokens
    _claimAllRewardsFor(user, user);

    uint256 userPLPTokenAmount = (lockdropStates[user].lockdropTokenAmount *
      totalPLPAmount) / totalAmount;

    // Lockdrop withdraw PLP Token from PLP staking
    lockdropConfig.plpStaking().withdraw(
      address(lockdropConfig.plpToken()),
      userPLPTokenAmount
    );

    // Lockdrop transfer for withdrawn PLP to gateway.
    lockdropConfig.plpToken().safeTransfer(msg.sender, userPLPTokenAmount);
    delete lockdropStates[user];
    emit LogWithdrawAll(user, address(lockdropToken));
  }

  /// @dev Owner of the contract can allocate P88
  /// @param amount Number of P88 that feeder will feed
  function allocateP88(uint256 amount)
    external
    onlyAfterLockdropPeriod
    onlyOwner
    nonReentrant
  {
    // Prevent multiple call
    if (totalP88 > 0) revert Lockdrop_AlreadyAllocateP88();
    totalP88 = amount;
    lockdropConfig.p88Token().safeTransferFrom(
      address(owner()),
      address(this),
      amount
    );
    emit LogAllocateP88(amount);
  }

  /// @dev Users can claim their P88, this is a one time claim
  /// @param user Address of the user that wants to claim P88
  function claimAllP88(address user)
    external
    onlyAfterLockdropPeriod
    nonReentrant
    returns (uint256)
  {
    if (lockdropStates[msg.sender].lockdropTokenAmount == 0)
      revert Lockdrop_NoPosition();
    if (totalP88 == 0) revert Lockdrop_ZeroTotalP88NotAllowed();
    if (totalP88Weight == 0) revert Lockdrop_ZeroP88WeightNotAllowed();
    if (lockdropStates[user].p88Claimed) revert Lockdrop_P88AlreadyClaimed();
    uint256 p88Amount = (totalP88 *
      lockdropStates[user].lockdropTokenAmount *
      lockdropStates[user].lockPeriod) / totalP88Weight;
    lockdropConfig.p88Token().safeTransfer(user, p88Amount);
    lockdropStates[user].p88Claimed = true;
    emit LogClaimAllP88(user, p88Amount);
    return p88Amount;
  }

  function _harvestAll() internal returns (uint256[] memory) {
    uint256 length = rewardTokens.length;
    uint256[] memory rewardBeforeHarvest = new uint256[](length);
    uint256[] memory harvestedReward = new uint256[](length);
    for (uint256 i = 0; i < length; ) {
      // check if is native token or ERC20
      if (rewardTokens[i] == nativeTokenAddress) {
        rewardBeforeHarvest[i] = address(this).balance;
      } else {
        rewardBeforeHarvest[i] = IERC20Upgradeable(rewardTokens[i]).balanceOf(
          address(this)
        );
      }

      unchecked {
        ++i;
      }
    }

    lockdropConfig.plpStaking().harvest(
      lockdropConfig.plpStaking().getStakingTokenRewarders(
        address(lockdropConfig.plpToken())
      )
    );

    for (uint256 i = 0; i < length; ) {
      if (rewardTokens[i] == nativeTokenAddress) {
        harvestedReward[i] = address(this).balance - rewardBeforeHarvest[i];
      } else {
        harvestedReward[i] =
          IERC20Upgradeable(rewardTokens[i]).balanceOf(address(this)) -
          rewardBeforeHarvest[i];
      }

      unchecked {
        ++i;
      }
    }

    return harvestedReward;
  }

  function _allPendingReward() internal view returns (uint256[] memory) {
    uint256 length = rewardTokens.length;
    uint256[] memory harvestedReward = new uint256[](length);

    address[] memory rewarders = lockdropConfig
      .plpStaking()
      .getStakingTokenRewarders(address(lockdropConfig.plpToken()));

    for (uint256 i = 0; i < length; ) {
      uint256 _pendingReward = IRewarder(rewarders[i]).pendingReward(
        address(this)
      );
      harvestedReward[i] = _pendingReward;

      unchecked {
        ++i;
      }
    }

    return harvestedReward;
  }

  function _calculateAccPerShare(uint256 claimedReward)
    internal
    view
    returns (uint256)
  {
    uint256 totalStakedPLPAmount = lockdropConfig
      .plpStaking()
      .getUserTokenAmount(address(lockdropConfig.plpToken()), address(this));

    return
      (totalStakedPLPAmount > 0)
        ? (claimedReward * 1e12) / totalStakedPLPAmount
        : 0;
  }

  function _transferUserReward(
    address user,
    address receiver,
    uint256[] memory harvestedRewards
  ) internal {
    uint256 userShare = (lockdropStates[user].lockdropTokenAmount *
      totalPLPAmount) / totalAmount;

    uint256 length = rewardTokens.length;
    for (uint256 i = 0; i < length; ) {
      // Update PLP accumurate per share
      accRewardPerShares[i] += _calculateAccPerShare(harvestedRewards[i]);

      uint256 userAccumReward = ((userShare * accRewardPerShares[i]) / 1e12);

      // calculate pending reward to be received for user
      uint256 pendingReward = userAccumReward -
        lockdropStates[user].userRewardDebts[i];

      // Transfer reward to user
      if (rewardTokens[i] == nativeTokenAddress) {
        payable(receiver).transfer(pendingReward);
      } else {
        IERC20Upgradeable(rewardTokens[i]).safeTransfer(
          receiver,
          pendingReward
        );
      }

      // calculate for update user reward dept
      lockdropStates[user].userRewardDebts[i] = userAccumReward;
      emit LogClaimReward(user, rewardTokens[i], pendingReward);
      unchecked {
        ++i;
      }
    }
  }

  function pendingReward(address user)
    external
    view
    returns (uint256[] memory)
  {
    uint256[] memory harvestedRewards = _allPendingReward();
    uint256 userShare = totalAmount > 0
      ? (lockdropStates[user].lockdropTokenAmount * totalPLPAmount) /
        totalAmount
      : 0;

    uint256 length = rewardTokens.length;
    uint256[] memory pendingRewards = new uint256[](length);
    for (uint256 i = 0; i < length; ) {
      // Update PLP accumurate per share
      uint256 _accRewardPerShares = accRewardPerShares[i] +
        _calculateAccPerShare(harvestedRewards[i]);

      uint256 userAccumReward = ((userShare * _accRewardPerShares) / 1e12);

      // calculate pending reward to be received for user
      uint256 pendingRewardOfThisToken = lockdropStates[user].lockPeriod > 0
        ? userAccumReward - lockdropStates[user].userRewardDebts[i]
        : 0;
      pendingRewards[i] = pendingRewardOfThisToken;
      unchecked {
        ++i;
      }
    }
    return pendingRewards;
  }

  /// @dev Users can claim all their reward
  /// @param user Address of the user that wants to claim the reward
  function claimAllRewards(address user)
    external
    onlyAfterLockdropPeriod
    nonReentrant
  {
    _claimAllRewardsFor(user, user);
  }

  /// @dev Receiver can claim users reward
  /// @param user Address of user that own the reward
  /// @param receiver Address of receiver that claim the reward for user
  function claimAllRewardsFor(address user, address receiver)
    external
    onlyLockdropCompounder
    onlyAfterLockdropPeriod
    nonReentrant
  {
    _claimAllRewardsFor(user, receiver);
  }

  function _claimAllRewardsFor(address user, address receiver) internal {
    uint256[] memory harvestedRewards = _harvestAll();
    // Reward will be transfer to receiver instead of user, user reward state will be kept
    _transferUserReward(user, receiver, harvestedRewards);
  }

  /// @dev PLP token is staked after the lockdrop period
  /// Recieve number of PLP after staking ERC20 Token
  function stakePLP() external onlyAfterLockdropPeriod onlyOwner {
    if (totalPLPAmount > 0) revert Lockdrop_PLPAlreadyStaked();
    // add lockdrop token to liquidity pool.
    lockdropToken.approve(address(poolRouter), totalAmount);
    lockdropConfig.plpToken().approve(
      address(lockdropConfig.plpStaking()),
      type(uint256).max
    );
    lockdropConfig.plpToken().approve(address(poolRouter), type(uint256).max);
    totalPLPAmount = poolRouter.addLiquidity(
      pool,
      address(lockdropToken),
      totalAmount,
      address(this),
      0
    );
    emit LogStakePLP(totalPLPAmount);
  }

  receive() external payable {}

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
