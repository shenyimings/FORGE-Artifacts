// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/**
 * @dev Interface for Vesper Pool Rewards.
 */
interface IPoolRewards {

    function claimReward(address) external;

    function claimable(address) external view returns (uint256);
}