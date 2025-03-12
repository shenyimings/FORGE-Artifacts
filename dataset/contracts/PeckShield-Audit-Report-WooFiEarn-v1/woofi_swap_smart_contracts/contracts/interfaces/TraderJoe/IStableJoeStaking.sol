// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IStableJoeStaking {
    function deposit(uint256 _amount) external;

    function getUserInfo(address _user, address _rewardToken) external view returns (uint256, uint256);

    function rewardTokensLength() external view returns (uint256);

    function pendingReward(address _user, address _token) external view returns (uint256);

    function withdraw(uint256 _amount) external;

    function emergencyWithdraw() external;

    function updateReward(address _token) external;
}
