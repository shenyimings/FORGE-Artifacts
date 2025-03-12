// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '../staking/interfaces/IStaking.sol';
import './interfaces/IMintableBurnableToken.sol';
import '../dex/LiquidityValueCalculator.sol';
import '../utils/BasisPointNumberMath.sol';
import './NonTransferableToken.sol';
import '../utils/ArrayUtils.sol';
import '../utils/LockableAsset.sol';

/**
 * @dev Struct to hold user's stake.
 * @param lockableAssetIndex The index of the lockable asset in the lockableAssets array.
 * @param stakingContractIndex The index of the staking contract in the stakingContracts array.
 * @param amountLocked The amount of the lockable asset that is locked.
 * @param amountMinted The amount of the token that is minted, taking multipliers into account.
 * @param lockPeriod The lock period of the stake (duration in seconds and reward modifier in basis points)
 * @param depositTimestamp The timestamp of the deposit.
 * @param unlockAvailibleTimestamp The timestamp when the stake can be unlocked.
 * @param isOngoing Whether the stake is ongoing or not. If false, it means that the stake has been withdrawn.
 */
struct Deposit {
  uint256 lockableAssetIndex;
  uint256 stakingContractIndex;
  uint256 amountLocked;
  uint256 amountMinted;
  LockPeriod lockPeriod;
  uint256 depositTimestamp;
  uint256 unlockAvailibleTimestamp;
  bool isOngoing;
}

error MultiERC20WeightedLocker__InvalidLockableAssetIndex();
error MultiERC20WeightedLocker__InvalidStakingContractIndex();
error MultiERC20WeightedLocker__InvalidLockPeriodId();
error MultiERC20WeightedLocker__InvalidRewardModifier();
error MultiERC20WeightedLocker__DepositIsNotOngoing();
error MultiERC20WeightedLocker__DepositIsStillLocked();
error MultiERC20WeightedLocker__DepositIsNotLocked();
error MultiERC20WeightedLocker__DepositsInThisAssetHaveBeenDisabled();
error MultiERC20WeightedLocker__AddressAlreadyExists();
error MultiERC20WeightedLocker__AssetDoesNotExists();
error MultiERC20WeightedLocker__DepositCanBeWithdrawnNormally();
error MultiERC20WeightedLocker__InvalidSlashingPenaltyPercentage();

/**
 * @notice This contract is responsible for locking tokens, managing the deposits to staking contracts
 * and minting governance tokens. It is also responsible for calculating the reward modifiers. Owner of this contract
 * can add new lockable assets.
 * @dev This contract is implementing ERC20 interface, but it is not transferable. If users want to transfer the token,
 * they have to withdraw the stake first.
 */
contract MultiERC20WeightedLocker is
  ERC20,
  ERC20Burnable,
  ERC20Permit,
  NonTransferableToken,
  Ownable
{
  using Counters for Counters.Counter;
  using BasisPointNumberMath for uint256;
  using ArrayUtils for IStaking[];
  using ArrayUtils for LockableAsset[];
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;
  using LiquidityValueCalculator for IUniswapV2TwapOracle;

  event DepositCreated(
    address indexed user,
    uint256 indexed depositId,
    address lockedAssetAddress,
    address stakingContractAddress,
    uint256 amountLocked,
    uint256 amountMinted,
    uint256 lockPeriodDuration,
    uint256 depositTimestamp,
    uint256 unlockAvailibleTimestamp
  );
  event RewardsCollected(
    address indexed user,
    address stakingContractAddress,
    address rewardAssetAddress,
    uint256 amount,
    uint256 timestamp
  );
  event DepositWithdrawn(
    address indexed user,
    uint256 indexed depositId,
    address lockedAssetAddress,
    address stakingContractAddress,
    uint256 unlockTimestamp
  );
  event DepositLiquidated(
    address indexed user,
    uint256 indexed depositId,
    address lockedAssetAddress,
    address stakingContractAddress,
    address liquidator,
    uint256 timestamp
  );

  /**
   * @dev the percentage of the deposit that is slashed when the deposit is withdrawn
   * in basis points e.g 500 = 5%
   */
  uint256 public slashingPenaltyPercentage = 500;

  /// @dev the deposit ID counter, each deposit has a unique ID
  Counters.Counter public currentDepositId;
  /// @dev user address => deposit ID => Deposit
  mapping(address => mapping(uint256 => Deposit)) public userDeposits;
  /// @dev user address => deposit ID
  mapping(address => uint256[]) public userDepositIds;
  /// @dev user address => amount of deposits made by the user
  mapping(address => uint256) public userDepositsCount;
  /// @dev list of all addresses that have deposited
  EnumerableSet.AddressSet private depositors;

  /// @dev list of lockable assets
  LockableAsset[] private lockableAssets;
  /// @dev lockable asset index => are deposits disabled for this asset
  mapping(uint256 => bool) public isDepositingDisabledForAsset;
  /// @dev token address => amount slashed
  mapping(address => uint256) public slashedTokensAmount;
  /// @dev user address => token address => amount locked
  mapping(address => mapping(address => uint256)) public userLockedAssetAmount;

  /// @dev staking contracts list
  IStaking[] public stakingContracts;

  /// @dev governance token address
  IMintableBurnableToken public immutable governanceToken;

  constructor(
    string memory _name,
    string memory _symbol,
    LockableAsset[] memory _lockableAssets,
    IMintableBurnableToken _governanceToken
  ) ERC20(_name, _symbol) ERC20Permit(_name) {
    for (uint256 i = 0; i < _lockableAssets.length; i++) {
      addLockableAsset(_lockableAssets[i]);
    }
    governanceToken = _governanceToken;
    currentDepositId.increment(); // so that the first deposit ID is 1
  }

  // ======== OWNER FUNCTIONS ========

  /**
   * @dev Adds a new staking contract to the list of staking contracts.
   * This function reverts if the staking contract passed as argument is already added.
   * @param _stakingContract The staking contract to be added.
   */
  function addStakingContract(IStaking _stakingContract) external onlyOwner {
    int256 existingElementIndex = stakingContracts.findElementInArray(_stakingContract);
    if (existingElementIndex >= 0) {
      revert MultiERC20WeightedLocker__AddressAlreadyExists();
    }
    stakingContracts.push(_stakingContract);
  }

  /**
   * @dev Adds a new lockable asset to the list of lockable assets.
   * This function reverts if the lockable asset passed as argument is already added.
   * @param _lockableAsset The lockable asset to be added.
   */
  function addLockableAsset(LockableAsset memory _lockableAsset) public onlyOwner {
    int256 existingElementIndex = lockableAssets.findElementInArray(_lockableAsset);
    if (existingElementIndex >= 0) {
      revert MultiERC20WeightedLocker__AddressAlreadyExists();
    }
    _addLockableAsset(_lockableAsset);
  }

  function _addLockableAsset(LockableAsset memory _lockableAsset) internal {
    for (uint i = 0; i < _lockableAsset.lockPeriods.length; i++) {
      if (
        _lockableAsset.lockPeriods[i].rewardModifier < BasisPointNumberMath.BASIS_POINT
      ) {
        revert MultiERC20WeightedLocker__InvalidRewardModifier();
      }
    }
    lockableAssets.push(_lockableAsset);
  }

  /**
   * @notice Updates the existing lockable asset by marking it as disabled for deposits and
   * adding a new lockable asset with modified properties.
   * @dev Because addLockableAsset reverts on duplicate lockable assets, this function can
   * be used to update properties of an existing lockable asset like the reward modifiers and lock periods.
   * @param _lockableAsset The lockable asset to be added.
   */
  function updateLockableAsset(LockableAsset memory _lockableAsset) public onlyOwner {
    int256 existingElementIndex = lockableAssets.findElementInArray(_lockableAsset);
    if (existingElementIndex == -1) {
      revert MultiERC20WeightedLocker__AssetDoesNotExists();
    }

    disableDepositsForAsset(uint256(existingElementIndex));

    _addLockableAsset(_lockableAsset);
  }

  /**
   * @notice Disables deposits for a lockable asset.
   * @param _lockableAssetIndex The index of the lockable asset.
   */
  function disableDepositsForAsset(uint256 _lockableAssetIndex) public onlyOwner {
    if (_lockableAssetIndex >= lockableAssets.length) {
      revert MultiERC20WeightedLocker__InvalidLockableAssetIndex();
    }
    isDepositingDisabledForAsset[_lockableAssetIndex] = true;
  }

  /**
   * @notice Enables deposits for a lockable asset.
   * @param _lockableAssetIndex The index of the lockable asset.
   */
  function enableDepositsForAsset(uint256 _lockableAssetIndex) external onlyOwner {
    if (_lockableAssetIndex >= lockableAssets.length) {
      revert MultiERC20WeightedLocker__InvalidLockableAssetIndex();
    }
    isDepositingDisabledForAsset[_lockableAssetIndex] = false;
  }

  /**
   * @notice Withdraws the slashed tokens from the contract.
   * @param _token The address of the token to be withdrawn.
   * @param _benficiary The address to which the tokens will be transferred.
   */
  function withdrawSlashedTokens(address _token, address _benficiary) external onlyOwner {
    uint256 amount = slashedTokensAmount[_token];
    slashedTokensAmount[_token] = 0;
    IERC20(_token).safeTransfer(_benficiary, amount);
  }

  /**
   * @notice Sets the slashing penalty percentage.
   * @param _slashingPenaltyPercentage The percentage of the stake that will be slashed.
   */
  function setSlashingPenaltyPercentage(
    uint256 _slashingPenaltyPercentage
  ) external onlyOwner {
    if (_slashingPenaltyPercentage > BasisPointNumberMath.BASIS_POINT) {
      revert MultiERC20WeightedLocker__InvalidSlashingPenaltyPercentage();
    }
    slashingPenaltyPercentage = _slashingPenaltyPercentage;
  }

  // ======== VIEW FUNCTIONS ========

  function getDeposit(
    address depositor,
    uint256 depositId
  ) external view returns (Deposit memory) {
    return userDeposits[depositor][depositId];
  }

  function getDepositorsCount() external view returns (uint256) {
    return depositors.length();
  }

  function getDepositor(uint256 index) external view returns (address) {
    return depositors.at(index);
  }

  function isDepositor(address account) external view returns (bool) {
    return depositors.contains(account);
  }

  function getLockableAsset(uint256 index) external view returns (LockableAsset memory) {
    return lockableAssets[index];
  }

  function getLockableAssetsCount() external view returns (uint256) {
    return lockableAssets.length;
  }

  function getStakingContract(uint256 index) external view returns (IStaking) {
    return stakingContracts[index];
  }

  function getStakingContractCount() external view returns (uint256) {
    return stakingContracts.length;
  }

  // ======== PUBLIC FUNCTIONS ========

  /**
   *  @notice Stake lockable asset to a selected staking contract and mint the governance token
   * taking the lock period into account. User can stake regular tokens or LP tokens of predefined pairs by
   * the contract owner.
   */
  function stake(
    uint256 _lockableAssetIndex,
    uint256 _stakingContractIndex,
    uint256 _amount,
    uint256 lockPeriodId
  ) public returns (uint256 depositId, uint256 mintedAmount) {
    if (_lockableAssetIndex >= lockableAssets.length)
      revert MultiERC20WeightedLocker__InvalidLockableAssetIndex();
    if (_stakingContractIndex >= stakingContracts.length) {
      revert MultiERC20WeightedLocker__InvalidStakingContractIndex();
    }
    if (isDepositingDisabledForAsset[_lockableAssetIndex]) {
      revert MultiERC20WeightedLocker__DepositsInThisAssetHaveBeenDisabled();
    }

    LockableAsset memory lockableAsset = lockableAssets[_lockableAssetIndex];
    if (lockPeriodId >= lockableAsset.lockPeriods.length) {
      revert MultiERC20WeightedLocker__InvalidLockPeriodId();
    }

    IStaking stakingContract = stakingContracts[_stakingContractIndex];

    uint256 initialDeposit = _amount;

    if (lockableAsset.isLPToken) {
      (uint256 lockedTokenAmount, ) = LiquidityValueCalculator.calculateLiquidityValue(
        IUniswapV2TwapOracle(lockableAsset.priceOracle),
        lockableAsset.dividendTokenFromPair,
        _amount
      );
      _amount = lockedTokenAmount;
    }

    IERC20(lockableAsset.token).safeTransferFrom(
      _msgSender(),
      address(this),
      initialDeposit
    );

    mintedAmount = _amount.applyModifierInBasisPoint(
      lockableAsset.lockPeriods[lockPeriodId].rewardModifier
    );
    _mint(_msgSender(), mintedAmount);
    if (lockableAsset.isEntitledToVote) {
      governanceToken.mint(_msgSender(), mintedAmount);
    }
    stakingContract.stakeFor(_msgSender(), mintedAmount);

    depositId = _addDeposit(
      _lockableAssetIndex,
      _stakingContractIndex,
      initialDeposit,
      mintedAmount,
      lockableAsset.lockPeriods[lockPeriodId]
    );

    emit DepositCreated(
      _msgSender(),
      depositId,
      lockableAsset.token,
      address(stakingContract),
      initialDeposit,
      mintedAmount,
      lockableAsset.lockPeriods[lockPeriodId].durationInSeconds,
      block.timestamp,
      userDeposits[_msgSender()][depositId].unlockAvailibleTimestamp
    );
  }

  /// @dev Wrapper for stake function for tokens supporting EIP-2612 permit functionality
  function stakeWithPermit(
    uint256 _lockableAssetIndex,
    uint256 _stakingContractIndex,
    uint256 _amount,
    uint256 lockPeriodId,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (uint256 depositId, uint256 mintedAmount) {
    if (_lockableAssetIndex >= lockableAssets.length)
      revert MultiERC20WeightedLocker__InvalidLockableAssetIndex();
    LockableAsset memory lockableAsset = lockableAssets[_lockableAssetIndex];
    IERC20Permit(lockableAsset.token).permit(
      _msgSender(),
      address(this),
      _amount,
      deadline,
      v,
      r,
      s
    );
    return stake(_lockableAssetIndex, _stakingContractIndex, _amount, lockPeriodId);
  }

  /// @notice Withdraw the locked asset, collect rewards and burn the governance token.
  function withdraw(uint256 _depositId) public {
    Deposit memory deposit = userDeposits[_msgSender()][_depositId];
    if (!deposit.isOngoing) {
      revert MultiERC20WeightedLocker__DepositIsNotOngoing();
    }
    if (deposit.unlockAvailibleTimestamp > block.timestamp) {
      revert MultiERC20WeightedLocker__DepositIsStillLocked();
    }

    LockableAsset memory lockableAsset = lockableAssets[deposit.lockableAssetIndex];

    IStaking stakingContract = stakingContracts[deposit.stakingContractIndex];

    _removeDeposit(lockableAsset, stakingContract, deposit, _depositId, _msgSender());

    IERC20(lockableAsset.token).safeTransfer(_msgSender(), deposit.amountLocked);

    emit DepositWithdrawn(
      _msgSender(),
      _depositId,
      lockableAsset.token,
      address(stakingContract),
      block.timestamp
    );
  }

  function withdrawStakeAndReward(uint256 _depositId) public returns (uint256 reward) {
    withdraw(_depositId);

    Deposit memory deposit = userDeposits[_msgSender()][_depositId];

    return collectRewards(deposit.stakingContractIndex);
  }

  /**
   * @notice Withdraw the locked asset even when the lock period is still active.
   * This action results in a loss of rewards.
   */
  function emergencyWithdraw(uint256 _depositId) public {
    Deposit memory deposit = userDeposits[_msgSender()][_depositId];
    if (!deposit.isOngoing) {
      revert MultiERC20WeightedLocker__DepositIsNotOngoing();
    }
    if (deposit.unlockAvailibleTimestamp < block.timestamp) {
      revert MultiERC20WeightedLocker__DepositCanBeWithdrawnNormally();
    }

    LockableAsset memory lockableAsset = lockableAssets[deposit.lockableAssetIndex];

    IStaking stakingContract = stakingContracts[deposit.stakingContractIndex];

    _removeDeposit(lockableAsset, stakingContract, deposit, _depositId, _msgSender());

    uint256 slashedAmount = deposit.amountLocked.applyModifierInBasisPoint(
      slashingPenaltyPercentage
    );
    slashedTokensAmount[lockableAsset.token] += slashedAmount;

    IERC20(lockableAsset.token).safeTransfer(
      _msgSender(),
      deposit.amountLocked - slashedAmount
    );

    emit DepositWithdrawn(
      _msgSender(),
      _depositId,
      lockableAsset.token,
      address(stakingContract),
      block.timestamp
    );
  }

  /// @notice Collect rewards from all deposits for a particular staking contract
  function collectRewards(uint256 _stakingContractIndex) public returns (uint256 reward) {
    if (_stakingContractIndex >= stakingContracts.length) {
      revert MultiERC20WeightedLocker__InvalidStakingContractIndex();
    }
    IStaking stakingContract = stakingContracts[_stakingContractIndex];

    reward = stakingContract.collectRewardsFor(_msgSender());

    emit RewardsCollected(
      _msgSender(),
      address(stakingContract),
      stakingContract.getRewardToken(),
      reward,
      block.timestamp
    );
  }

  function earnedReward(
    address _user,
    uint256 _stakingContractIndex
  ) public view returns (uint256 reward) {
    if (_stakingContractIndex >= stakingContracts.length) {
      revert MultiERC20WeightedLocker__InvalidStakingContractIndex();
    }
    IStaking stakingContract = stakingContracts[_stakingContractIndex];

    return stakingContract.earnedReward(_user);
  }

  /**
   * @dev Liquidate any user deposit which lock period is over. This is inspired by the Curve DAO
   * governance token boosting solution: https://curve.readthedocs.io/dao-gauges.html#boosting
   * Technically, if no one liquidates a stale deposit, the deposit owner will still receive more
   * rewards as if his tokens were still locked. However, it is in the interest of the community
   * to liquidate stale deposits to maximise their share of rewards to be distributed.
   */
  function liquidateStaleDeposit(address _user, uint256 _depositId) public {
    Deposit memory deposit = userDeposits[_user][_depositId];
    if (!deposit.isOngoing) {
      revert MultiERC20WeightedLocker__DepositIsNotOngoing();
    }
    if (deposit.unlockAvailibleTimestamp > block.timestamp) {
      revert MultiERC20WeightedLocker__DepositIsStillLocked();
    }
    if (deposit.lockPeriod.durationInSeconds == 0) {
      revert MultiERC20WeightedLocker__DepositIsNotLocked();
    }

    LockableAsset memory lockableAsset = lockableAssets[deposit.lockableAssetIndex];
    IStaking stakingContract = stakingContracts[deposit.stakingContractIndex];

    _removeDeposit(lockableAsset, stakingContract, deposit, _depositId, _user);

    IERC20(lockableAsset.token).safeTransfer(_user, deposit.amountLocked);

    emit DepositLiquidated(
      _user,
      _depositId,
      lockableAsset.token,
      address(stakingContract),
      _msgSender(),
      block.timestamp
    );
  }

  // ======== PRIVATE FUNCTIONS ========

  function _removeDeposit(
    LockableAsset memory _lockableAsset,
    IStaking _stakingContract,
    Deposit memory _deposit,
    uint256 _depositId,
    address _user
  ) private {
    userLockedAssetAmount[_user][
      lockableAssets[_deposit.lockableAssetIndex].token
    ] -= _deposit.amountLocked;
    _burn(_user, _deposit.amountMinted);

    if (_lockableAsset.isEntitledToVote) {
      governanceToken.burn(_user, _deposit.amountMinted);
    }

    _stakingContract.withdrawFor(_user, _deposit.amountMinted);

    userDeposits[_user][_depositId].isOngoing = false;
  }

  function _addDeposit(
    uint256 _lockableAssetIndex,
    uint256 _stakingContractIndex,
    uint256 _amount,
    uint256 _mintedAmount,
    LockPeriod memory lockPeriod
  ) internal returns (uint256 depositId) {
    uint256 depositTimestamp = block.timestamp;
    uint256 unlockAvailibleTimestamp = depositTimestamp + lockPeriod.durationInSeconds;

    userLockedAssetAmount[_msgSender()][
      lockableAssets[_lockableAssetIndex].token
    ] += _amount;

    depositId = _getAndIncrementDepositId();
    userDeposits[_msgSender()][depositId] = Deposit(
      _lockableAssetIndex,
      _stakingContractIndex,
      _amount,
      _mintedAmount,
      lockPeriod,
      depositTimestamp,
      unlockAvailibleTimestamp,
      true
    );

    userDepositIds[_msgSender()].push(depositId);
    userDepositsCount[_msgSender()]++;
    depositors.add(_msgSender());
  }

  function _getAndIncrementDepositId() internal returns (uint256 depositId) {
    depositId = currentDepositId.current();
    currentDepositId.increment();
  }

  // The following functions are overrides required by Solidity.

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override(ERC20, NonTransferableToken) {
    super._beforeTokenTransfer(from, to, amount);
  }
}
