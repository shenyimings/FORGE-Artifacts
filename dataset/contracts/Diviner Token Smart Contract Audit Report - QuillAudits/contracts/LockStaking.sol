// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

// Cộng vào phần cũ, không đếm lại 30 ngày
// Tính lại lãi mới

contract LockStaking is OwnableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IERC20Upgradeable public rewardToken;

  struct User {
    uint256 amount;
    uint256 firstTimeDeposit;
    uint256 expectedInterestEndStaking;
    uint256 lastTimeClaim;
    uint256 debt;
    uint256 rewardDebt; // Reward debt. See explanation below.
  }

  struct Pool {
    address token;
    uint256 totalAmount;
    uint256 lastRewardBlock; // Last block number that DPT distribution occurs.
    uint256 accDptPerShare; // Accumulated DPT per share, times 1e12. See below.
    uint256 rewardPerBlock;
    uint256 endBlock;
  }

  uint256 public nextPoolId;
  uint256 public round; // round will increace 1 when start new ido to save amount staked tokens of users

  mapping(uint256 => Pool) public pools;
  mapping(uint256 => mapping(address => User)) public users;
  mapping(address => mapping(uint256 => mapping(address => uint256))) // (userAddress => round => tokenAddress => amount)
    public userStakedAmount; // follow user staked

  mapping(uint256 => mapping(address => uint256)) public poolStakedAmount; // round => tokenAddress => amount

  event Deposit(address indexed user, uint256 amount);
  event Withdraw(address indexed user, uint256 amount);

  function initialize(IERC20Upgradeable _rewardToken) public initializer {
    __Ownable_init();
    __ReentrancyGuard_init_unchained();

    rewardToken = _rewardToken;
  }

  function saveStakedAmount() external onlyOwner {
    for (uint8 i = 0; i < nextPoolId + 1; i++) {
      poolStakedAmount[round][pools[i].token] += pools[i].totalAmount;
    }
    round++;
  }

  function getPools(uint256 from, uint256 to)
    external
    view
    returns (Pool[] memory)
  {
    require(to <= nextPoolId, "not match amount of pool");
    Pool[] memory result = new Pool[](to - from);

    for (uint256 i = from; i < to; i++) {
      result[i - from] = pools[i];
    }

    return result;
  }

  // Return reward multiplier over the given _from to _to block.
  function getMultiplier(
    uint256 poolId,
    uint256 _from,
    uint256 _to
  ) public view returns (uint256) {
    if (_to <= pools[poolId].endBlock) {
      return _to - _from;
    } else if (_from >= pools[poolId].endBlock) {
      return 0;
    } else {
      return pools[poolId].endBlock - _from;
    }
  }

  // View function to see pending Reward on frontend.
  function pendingReward(uint256 poolId, address _user)
    external
    view
    returns (uint256)
  {
    Pool storage pool = pools[poolId];
    User storage user = users[poolId][_user];
    uint256 accDptPerShare = pool.accDptPerShare;
    uint256 lpSupply = pool.totalAmount;

    if (block.number > pool.lastRewardBlock && lpSupply != 0) {
      uint256 multiplier = getMultiplier(
        poolId,
        pool.lastRewardBlock,
        block.number
      );
      uint256 dptReward = multiplier * pool.rewardPerBlock;
      accDptPerShare = accDptPerShare + (dptReward * 1e12) / lpSupply;
    }
    return (user.amount * accDptPerShare) / 1e12 - user.rewardDebt;
  }

  // Update reward variables of the given pool to be up-to-date.
  function updatePool(uint256 _pid) public {
    Pool storage pool = pools[_pid];
    if (block.number <= pool.lastRewardBlock) {
      return;
    }
    uint256 lpSupply = pool.totalAmount;

    if (lpSupply == 0) {
      pool.lastRewardBlock = block.number;
      return;
    }
    uint256 multiplier = getMultiplier(
      _pid,
      pool.lastRewardBlock,
      block.number
    );

    uint256 dptReward = multiplier * pool.rewardPerBlock;
    pool.accDptPerShare = pool.accDptPerShare + (dptReward * 1e12) / lpSupply;
    pool.lastRewardBlock = block.number;
  }

  function addPool(
    address[] memory token,
    uint256[] memory endBlock,
    uint256[] memory rewardPerBlock
  ) external onlyOwner {
    require(
      token.length == endBlock.length &&
        rewardPerBlock.length == endBlock.length,
      "not match amount filed"
    );
    uint256 length = token.length;
    for (uint256 i = 0; i < length; i++) {
      pools[nextPoolId + i].token = token[i];
      pools[nextPoolId + i].rewardPerBlock = rewardPerBlock[i];
      pools[nextPoolId + i].endBlock = endBlock[i];
      pools[nextPoolId + i].lastRewardBlock = block.number;
    }

    nextPoolId += length;
  }

  function updatePool(uint256 id, Pool memory pool) external onlyOwner {
    pools[id].token = pool.token;
    pools[id].rewardPerBlock = pool.rewardPerBlock;
    pools[id].endBlock = pool.endBlock;
  }

  // Stake SYRUP tokens to SmartChef
  function deposit(uint256 id, uint256 _amount) public {
    require(_amount > 0, "deposit zero amount");
    require(nextPoolId > id, "not exist pool");
    Pool storage pool = pools[id];
    User storage user = users[id][msg.sender];

    updatePool(id);

    if (user.amount > 0) {
      uint256 pending = ((user.amount * pool.accDptPerShare) / 1e12) -
        user.rewardDebt;

      if (pending > 0) {
        IERC20Upgradeable(pool.token).safeTransferFrom(
          msg.sender,
          address(this),
          pending
        );
      }
    }

    IERC20Upgradeable(pool.token).safeTransferFrom(
      msg.sender,
      address(this),
      _amount
    );
    user.amount += _amount;
    pool.totalAmount += _amount;
    userStakedAmount[msg.sender][round][pool.token] = user.amount;
    user.rewardDebt = (user.amount * pool.accDptPerShare) / 1e12;

    emit Deposit(msg.sender, _amount);
  }

  // Withdraw SYRUP tokens from STAKING.
  function withdraw(uint256 poolId, uint256 _amount) public {
    Pool storage pool = pools[poolId];
    User storage user = users[poolId][msg.sender];
    require(user.amount >= _amount, "withdraw: not good");
    updatePool(poolId);
    uint256 pending = (user.amount * pool.accDptPerShare) /
      1e12 -
      user.rewardDebt;

    if (pending > 0) {
      rewardToken.safeTransfer(address(msg.sender), pending);
    }
    if (_amount > 0) {
      user.amount -= _amount;
      pool.totalAmount -= _amount;
      userStakedAmount[msg.sender][round][pool.token] = user.amount;
      IERC20Upgradeable(pool.token).safeTransfer(msg.sender, _amount);
    }
    user.rewardDebt = (user.amount * pool.accDptPerShare) / 1e12;

    emit Withdraw(msg.sender, _amount);
  }
}
