// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

interface ILiquidityGaugePool {
  struct PoolInfo {
    bytes32 key;
    string name;
    string info;
    uint256 lockupPeriodInBlocks;
    uint256 epochDuration;
    uint256 veBoostRatio;
    uint256 platformFee;
    address stakingToken;
    address veToken;
    address rewardToken;
    address registry;
    address treasury;
  }

  event EpochRewardSet(bytes32 indexed key, address indexed triggeredBy, uint256 rewards);
  event EpochDurationUpdated(bytes32 indexed key, uint256 previous, uint256 current);
  event VotingPowersUpdated(bytes32 indexed key, address indexed triggeredBy, uint256 previous, uint256 current, uint256 previousTotal, uint256 currentTotal);
  event LiquidityGaugePoolSet(bytes32 indexed key, address indexed triggeredBy, address liquidityGaugePool, PoolInfo args);
  event LiquidityGaugeDeposited(bytes32 indexed key, address indexed account, address indexed stakingToken, uint256 amount);
  event LiquidityGaugeWithdrawn(bytes32 indexed key, address indexed account, address indexed stakingToken, uint256 amount);
  event LiquidityGaugeRewardsWithdrawn(bytes32 indexed key, address indexed account, address indexed treasury, uint256 rewards, uint256 platformFee);

  function deposit(uint256 amount) external;
  function withdraw(uint256 amount) external;
  function withdrawRewards() external;
  function exit() external;

  function setPool(PoolInfo calldata args) external;
  function setEpoch(uint256 epoch, uint256 epochDuration, uint256 rewards) external;
  function getKey() external view returns (bytes32);

  error WithdrawalLockedError(uint256 waitUntilHeight);
  error EpochUnavailableError();
  error PlatformFeeTooHighError(uint256 platformFee);
}
