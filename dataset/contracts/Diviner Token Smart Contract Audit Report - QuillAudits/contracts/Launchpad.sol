// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import "./ILockStaking.sol";

contract Launchpad is OwnableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  uint256 public constant PRECISION = 1000000; // 1 mil

  IERC20Upgradeable public rewardToken;
  address public lockStakingAddress;
  address public dptAddress;
  address public lpAddress;

  struct User {
    uint256 amount;
    uint256 firstTimeDeposit;
    uint256 expectedInterestEndStaking;
    uint256 claimedMark;
  }

  struct Pool {
    uint256 id;
    uint256 totalAmount;
    address depositToken;
    address releaseToken;
    uint256 releaseAmount;
    uint256 stakingRound;
    uint256 releaseRate;
    uint256 buyRate; //
    uint256 endTime;
  }

  uint256 public nextPoolId;

  uint256 lpAndDptRate; // 1 lp = ??? dpt
  uint256 public timeLocking; // time lock in each phrase: 1 month, 25% token will be send

  mapping(uint256 => Pool) public pools;
  mapping(uint256 => mapping(address => User)) public users;

  function initialize(
    IERC20Upgradeable _rewardToken,
    address _dptAddress,
    address _lpAddress,
    uint256 _lpAndDptRate,
    address _lockStakingAddress
  ) public initializer {
    __Ownable_init();
    __ReentrancyGuard_init_unchained();

    dptAddress = _dptAddress;
    rewardToken = _rewardToken;
    lpAddress = _lpAddress;
    lpAndDptRate = _lpAndDptRate;
    lockStakingAddress = _lockStakingAddress;

    timeLocking = 30 days;
  }

  function getUserStakedAmount(uint256 poolId, address user)
    internal
    view
    returns (uint256)
  {
    return
      ILockStaking(lockStakingAddress).userStakedAmount(
        user,
        pools[poolId].stakingRound,
        dptAddress
      ) +
      ILockStaking(lockStakingAddress).userStakedAmount(
        user,
        pools[poolId].stakingRound,
        lpAddress
      ) *
      lpAndDptRate;
  }

  function getAmountUserCanBuy(uint256 poolId, address user)
    public
    view
    returns (uint256)
  {
    return
      (getUserStakedAmount(poolId, user) * pools[poolId].buyRate) / PRECISION;
  }

  function addPool(
    address depositToken,
    address releaseToken,
    uint256 releaseAmount,
    uint256 stakingRound,
    uint256 releaseRate,
    uint256 endTime
  ) external onlyOwner {
    uint256 parseTokenAmount = ILockStaking(lockStakingAddress)
      .poolStakedAmount(stakingRound, dptAddress) +
      ILockStaking(lockStakingAddress).poolStakedAmount(
        stakingRound,
        lpAddress
      ) *
      lpAndDptRate;

    pools[nextPoolId].buyRate = (releaseAmount * PRECISION) / parseTokenAmount;
    pools[nextPoolId].depositToken = depositToken;
    pools[nextPoolId].releaseToken = releaseToken;
    pools[nextPoolId].releaseAmount = releaseAmount;
    pools[nextPoolId].stakingRound = stakingRound;
    pools[nextPoolId].releaseRate = releaseRate;
    pools[nextPoolId].endTime = block.timestamp + endTime;

    nextPoolId++;
  }

  function deposit(uint256 poolId, uint256 _amount) external nonReentrant {
    require(_amount > 0, "deposit zero amount");
    require(nextPoolId > poolId, "not exist pool");
    require(block.timestamp < pools[poolId].endTime, "End pool");
    uint256 amountUserCanDeposit = getAmountUserCanBuy(poolId, msg.sender);
    User storage userInfo = users[poolId][msg.sender];
    Pool memory poolInfo = pools[poolId];

    require(
      userInfo.amount + _amount <= amountUserCanDeposit,
      "exceed amount can deposit"
    );

    userInfo.amount += _amount;
    poolInfo.totalAmount += _amount;

    IERC20Upgradeable(poolInfo.depositToken).safeTransferFrom(
      msg.sender,
      address(this),
      _amount
    );
  }

  function claim(uint256 poolId) external nonReentrant {
    User storage userInfo = users[poolId][msg.sender];
    require(userInfo.amount > 0, "not deposit, can't withdraw");
    uint256 claimMark = (block.timestamp < pools[poolId].endTime)
      ? 0
      : (block.timestamp - pools[poolId].endTime) / timeLocking + 1;

    require(
      userInfo.claimedMark < claimMark,
      "you claimed reward or not in claiming time"
    );

    uint256 claimedAmount = ((userInfo.amount / 4) *
      (claimMark - userInfo.claimedMark)) * pools[poolId].releaseRate;
    userInfo.claimedMark = claimMark;

    IERC20Upgradeable(pools[poolId].releaseToken).safeTransfer(
      msg.sender,
      claimedAmount
    );
  }
}
