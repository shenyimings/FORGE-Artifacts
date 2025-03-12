//contracts/Farms.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./EVRYDistributor.sol";

contract Farms is ReentrancyGuardUpgradeable, OwnableUpgradeable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // Info of each user.
  struct UserInfo {
    uint256 amount; // How many Staking tokens the user has provided.
    uint256 rewardDebt; // Reward debt. See explanation below.
    address fundedBy; // Funded by who?
  }

  /// @notice Info of each pool.
  struct PoolInfo {
    IERC20 lpToken;
    uint256 allocPoint; // How many allocation points assigned to this pool. EVRY's to distribute per block.
    uint256 lastRewardBlock; // Last block number that EVRYs distribution occurs.
    uint256 accEVRYPerShare; // Accumulated EVRYs per share, times 1e12. See below.
  }

  /// @notice EVRY Distributor to control farm evry reward
  EVRYDistributor public evryDistributor;

  /// @notice Platform token
  IERC20 public evry;

  /// @notice Emission rate of farm product
  uint256 public evryPerBlock;

  /// @notice Remaining minted but haven't claim from 
  uint256 public evrySupply;

  /// @notice Info of each pool.
  PoolInfo[] public poolInfo;

  /// @notice Address of the ERC-20 for each Pool.
  IERC20[] public stakeTokens;

  /// @notice Info of each user that stakes tokens.
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;
  /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
  uint256 private totalAllocPoint;

  // 1e12 is 0.000001 (decimal 18)
  uint256 private constant ACC_EVRY_PRECISION = 1e12;

  event AddPool(uint256 indexed pid, uint256 allocPoint, IERC20 indexed lpToken);
  event SetPoolAllocation(uint256 indexed pid, uint256 allocPoint);
  event UpdatePool(uint256 indexed pid, uint256 lastRewardBlock, uint256 lpSupply, uint256 accEVRYPerShare);
  event Deposit(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
  event Withdraw(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
  event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
  event SetEvryPerBlock(address indexed sender, uint256 evryPerBlock);


  function initialize(
    EVRYDistributor _evryDistributor,
    uint256 _evryPerBlock
  ) public initializer {
    __Ownable_init();
    __ReentrancyGuard_init();

    evryDistributor = _evryDistributor;
    evry = evryDistributor.evry();
    evryPerBlock = _evryPerBlock;
  }

  function setEvryPerBlock(uint256 _evryPerBlock) external onlyOwner {
    massUpdatePools();
    evryPerBlock = _evryPerBlock;

    emit SetEvryPerBlock(msg.sender, _evryPerBlock);
  }

  /// @notice Add a new lp to the pool. Can only be called by the owner.
  /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
  /// @param allocPoint AP of the new pool
  /// @param _stakeToken address of the LP token
  function addPool(
    uint256 allocPoint,
    IERC20 _stakeToken,
    uint256 _startBlock
  ) external onlyOwner {
    require(!isDuplicatedPool(_stakeToken), "Farms::addPool:: stakeToken dup");

    massUpdatePools();

    uint256 lastRewardBlock = block.number > _startBlock ? block.number : _startBlock;
    totalAllocPoint = totalAllocPoint.add(allocPoint);

    stakeTokens.push(_stakeToken);

    poolInfo.push(
      PoolInfo({ lpToken: _stakeToken, allocPoint: allocPoint, lastRewardBlock: lastRewardBlock, accEVRYPerShare: 0 })
    );
    emit AddPool(stakeTokens.length.sub(1), allocPoint, _stakeToken);
  }

  /// @notice Update the given pool's EVRYToken allocation point contract. Can only be called by the owner.
  /// @param _pid The index of the pool. See `poolInfo`.
  /// @param _allocPoint new AP of the pool
  function setPoolAllocation(uint256 _pid, uint256 _allocPoint) external onlyOwner {
    massUpdatePools();

    // Remove current AP value of pool _pid from total AP, then add new one.
    totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);

    // Replace old AP value with new one.
    poolInfo[_pid].allocPoint = _allocPoint;

    emit SetPoolAllocation(_pid, _allocPoint);
  }

  /// @notice Deposit LP tokens for EVRY allocation.
  /// @param _for The address that will get yield
  /// @param pid The index of the pool. See `poolInfo`.
  /// @param amount to deposit.
  function deposit(
    address _for,
    uint256 pid,
    uint256 amount
  ) external nonReentrant {
    PoolInfo memory pool = updatePool(pid);
    UserInfo storage user = userInfo[pid][_for];

    // Validation
    if (user.fundedBy != address(0)) require(user.fundedBy == msg.sender, "Farms::deposit:: bad sof");

    // Effects
    _harvest(_for, pid);

    uint256 preAmount = stakeTokens[pid].balanceOf(address(this));
    stakeTokens[pid].safeTransferFrom(msg.sender, address(this), amount);
    uint256 postAmount = stakeTokens[pid].balanceOf(address(this));
    uint256 actualAmount = postAmount.sub(preAmount);

    user.amount = user.amount.add(actualAmount);
    user.rewardDebt = user.rewardDebt.add(actualAmount.mul(pool.accEVRYPerShare) / ACC_EVRY_PRECISION);
    if (user.fundedBy == address(0)) user.fundedBy = msg.sender;

    // Interactions
    if (isEvryPool(pool.lpToken)) evrySupply = evrySupply.add(actualAmount);

    emit Deposit(msg.sender, pid, actualAmount, _for);
  }

  /// @notice Withdraw LP tokens.
  /// @param _for Receiver of yield
  /// @param pid The index of the pool. See `poolInfo`.
  /// @param amount of lp tokens to withdraw.
  function withdraw(
    address _for,
    uint256 pid,
    uint256 amount
  ) external nonReentrant {
    PoolInfo memory pool = updatePool(pid);
    UserInfo storage user = userInfo[pid][_for];

    require(user.fundedBy == msg.sender || msg.sender == _for, "Farms::withdraw:: only funder");
    require(user.amount >= amount, "Farms::withdraw:: amount exceeds");

    // Effects
    _harvest(_for, pid);

    user.rewardDebt = user.rewardDebt.sub(amount.mul(pool.accEVRYPerShare) / ACC_EVRY_PRECISION);
    user.amount = user.amount.sub(amount);
    
    // Interactions
    stakeTokens[pid].safeTransfer(user.fundedBy, amount);
    if (user.amount == 0) user.fundedBy = address(0);
    if (isEvryPool(pool.lpToken)) evrySupply = evrySupply.sub(amount);

    emit Withdraw(msg.sender, pid, amount, _for);
  }

  //@notice Harvest EVRYs earn from all pool contains thier positon.
  function harvestAll() external {
    uint256 length = poolInfo.length;
    for (uint256 _pid = 0; _pid < length; _pid++) {
      UserInfo storage user = userInfo[_pid][msg.sender];
      if (user.amount > 0) {
        updatePool(_pid);
        _harvest(msg.sender, _pid);
      }
    }
  }

  // Harvest EVRYs earn from the pool.
  function harvest(uint256 _pid) external {
    updatePool(_pid);
    _harvest(msg.sender, _pid);
  }

  /// @notice Returns the number of pools.
  function poolLength() external view returns (uint256) {
    return poolInfo.length;
  }

  function pendingReward(uint256 _pid, address _user) external view returns (uint256) {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    uint256 accEVRYPerShare = pool.accEVRYPerShare;
    uint256 stakeTokenSupply;
    if (isEvryPool(pool.lpToken)) {
      stakeTokenSupply = evrySupply;
    } else {
      stakeTokenSupply = stakeTokens[_pid].balanceOf(address(this));
    }

    if (block.number > pool.lastRewardBlock && stakeTokenSupply != 0) {
      uint256 blocks = block.number.sub(pool.lastRewardBlock);
      uint256 evryReward = (blocks.mul(evryPerBlock).mul(pool.allocPoint).mul(ACC_EVRY_PRECISION)).div(totalAllocPoint);
      accEVRYPerShare = accEVRYPerShare.add(evryReward.div(stakeTokenSupply));
    }
    uint256 _pendingReward = (user.amount.mul(accEVRYPerShare) / ACC_EVRY_PRECISION).sub(user.rewardDebt);

    return _pendingReward;
  }

  /// @notice Update reward variables of the given pool.
  /// @param pid The index of the pool. See `poolInfo`.
  /// @return pool returns the Pool that was updated
  function updatePool(uint256 pid) public returns (PoolInfo memory pool) {
    pool = poolInfo[pid];
    if (block.number > pool.lastRewardBlock) {
      uint256 stakeTokenSupply;
      if (isEvryPool(pool.lpToken)) {
        stakeTokenSupply = evrySupply;
      } else {
        stakeTokenSupply = stakeTokens[pid].balanceOf(address(this));
      }
      if (stakeTokenSupply > 0 && totalAllocPoint > 0) {
        uint256 blocks = block.number.sub(pool.lastRewardBlock);
        uint256 evryReward = (blocks.mul(evryPerBlock).mul(pool.allocPoint)).div(totalAllocPoint);

        uint256 evryReleased = evryDistributor.release(evryReward);

        pool.accEVRYPerShare = pool.accEVRYPerShare.add((evryReleased.mul(ACC_EVRY_PRECISION)).div(stakeTokenSupply));
      }
      pool.lastRewardBlock = block.number;
      poolInfo[pid] = pool;
      emit UpdatePool(pid, pool.lastRewardBlock, stakeTokenSupply, pool.accEVRYPerShare);
    }
  }

  /// @notice Harvest proceeds for transaction sender to `to`.
  /// @param pid The index of the pool. See `poolInfo`.
  /// @param to Receiver of EVRY rewards.
  function _harvest(address to, uint256 pid) internal {
    PoolInfo storage pool = poolInfo[pid];
    UserInfo storage user = userInfo[pid][to];
    uint256 accumulatedEvry = user.amount.mul(pool.accEVRYPerShare).div(ACC_EVRY_PRECISION);
    uint256 _pendingEvry = accumulatedEvry.sub(user.rewardDebt);
    if (_pendingEvry == 0) {
      return;
    }

    // Effects
    user.rewardDebt = accumulatedEvry;

    evry.safeTransfer(to, _pendingEvry);

    emit Harvest(msg.sender, pid, _pendingEvry);
  }

  /// @notice Returns if stakeToken is duplicated
  function isDuplicatedPool(IERC20 _stakeToken) internal view returns (bool) {
    uint256 length = poolInfo.length;
    for (uint256 _pid = 0; _pid < length; _pid++) {
      if (stakeTokens[_pid] == _stakeToken) return true;
    }
    return false;
  }

  /// @notice Returns if stakeToken is evry
  function isEvryPool(IERC20 _stakeToken) internal view returns (bool) {
    return _stakeToken == evry;
  }

  function massUpdatePools() public {
    uint256 length = poolInfo.length;
    for (uint256 pid = 0; pid < length; pid++) {
      updatePool(pid);
    }
  }

}
