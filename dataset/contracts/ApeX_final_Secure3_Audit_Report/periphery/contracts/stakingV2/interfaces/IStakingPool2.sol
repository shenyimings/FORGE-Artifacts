// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IStakingPool2 {
    event Deposited(address indexed user, uint256 amount, uint256 shares, uint256 period, uint256 expireAt);
    event Withdrawn(address indexed user, address indexed to, uint256 amount);
    event RewardClaimed(address indexed user, address indexed to, uint256 claimed);
    event SharesTransferred(address indexed from, address indexed to, uint256 amount);
    event RewardsPerSecondUpdated(uint256 oldRewards, uint256 newRewards);
    event EndTimeUpdated(uint256 oldEndTime, uint256 newEndTime);
    event MinPeriodUpdated(uint256 oldMinPeriod, uint256 newMinPeriod);
    event DistributedUserReward(address indexed user, uint256 userRewardDelta, uint256 poolRewardIndex);

    function stakeToken() external view returns (address);

    function rewardToken() external view returns (address);

    function rewardsPerSecond() external view returns (uint256);

    function endTime() external view returns (uint256);

    function minPeriod() external view returns (uint256);

    function totalShares() external view returns (uint256);

    function poolRewardState() external view returns (uint256 index, uint256 timestamp);

    function getUserIndex(address user) external view returns (uint256);

    function getUserShares(address user) external view returns (uint256);

    function getUserCurrentDeposit(address user) external view returns (uint256);

    function getUserRewardAccrued(address user) external view returns (uint256);

    function rewardClaimable(address user) external view returns (uint256);

    function withdrawable(address user) external view returns (uint256);

    function currentDeposit(uint256 amount) external;

    function fixedDeposit(uint256 amount, uint256 period, uint256 preExpireAt) external;

    function withdraw(address to, uint256 amount) external;

    function claimReward(address to) external returns (uint256 claimed);
}
