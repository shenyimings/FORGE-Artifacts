// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IRewardsGauge {
    function balanceOf(address account) external view returns (uint256);

    function claimable_reward(address user, address token) external view returns (uint256);

    function claim_rewards(address user) external;

    function deposit(uint256 value) external;

    function withdraw(uint256 value) external;
}
