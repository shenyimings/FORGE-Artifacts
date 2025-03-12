// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

interface YieldWorker {
    function farmToken() external view returns (address);

    function farmRewardToken() external view returns (address);

    function userRewardToken() external view returns (address);

    function pendingReward() external view returns (uint256);

    function deposit() external;

    function withdraw(uint256) external;

    function claimReward(uint256) external;

    function work() external;

    function emergencyWithdraw() external;
}
