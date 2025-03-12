// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IRewardDistributor {
    event Distribute(uint256 amount);
    event TokensPerIntervalChange(uint256 amount);

    function rewardToken() external view returns (address);
    function tokensPerInterval() external view returns (uint256);
    function pendingRewards() external view returns (uint256);
    function distribute() external returns (uint256);
}
