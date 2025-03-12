// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

interface Vault {
    function farmToken() external view returns (address);
    function rewardToken() external view returns (address);
    function pendingReward() external view returns (uint256);
    function totalRewardPerShare() external view returns (uint256);
    function userPendingReward(address) external view returns (uint256);
    function deposit(uint256) external;
    function withdraw(uint256) external;
    function withdrawAll() external;
    function work() external;
    function updateVault() external;
}