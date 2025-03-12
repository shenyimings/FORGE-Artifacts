// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// REFACTOR
interface IRewarder {
    function onMntReward(address user, uint256 newLpAmount) external;

    function onEmergencyWithdraw(address user) external;

    function pendingTokens(address user) external view returns (uint256 pending);

    function rewardToken() external view returns (address);
}