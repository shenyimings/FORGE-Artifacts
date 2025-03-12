//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @title IReward
 * @dev Reward Interface for greenproof contracts
 * @author EnergyWeb Foundation
 */
interface IReward {
    /**
     * @dev Emitted when the reward pool is replenished
     * @param amount The amount added to the reward pool
     */
    event Replenished(uint256 indexed amount);

    /**
     * @dev Emitted when rewards are activated
     * @param activationDate The date when rewards were activated
     */
    event RewardsActivated(uint256 indexed activationDate);

    /**
     * @dev Emitted when rewards are deactivated
     * @param deactivationDate The date when rewards were deactivated
     */
    event RewardsDeactivated(uint256 indexed deactivationDate);

    /**
     * @dev Emitted when rewards are paid out
     * @param numberOfRewards The number of rewards paid out
     */
    event RewardsPaidOut(uint256 indexed numberOfRewards);

    /**
     * @notice replenishRewardPool - Allows the refunding of the contract to reward workers
     * @dev This function will revert if reward feature is disabled.
     * @dev When rewards are enabled, the transaction will revert if sent withoud providig funds into `msg.value`
     */
    function replenishRewardPool() external payable;

    /**
     * @notice setRewardsEnabled - Enables/disables the rewards feature.
     * @dev Only the contract owner can call this function. This restriction is set on the internal `setRewardsFeature` function.
     * @dev The transaction will revert if the function is called while the rewarding is already in the desired state intor the `rewardStorage`
     * @param rewardsEnabled - The status of rewarding feature
     */
    function setRewardsEnabled(bool rewardsEnabled) external;

    /**
     * @notice payReward - Allows to manually send rewards to workers waiting in the reward queue
     * @dev This function will revert when the reward feature is disabled
     * @param numberOfPays - The number of workers who have been rewarded
     */
    function payReward(uint256 numberOfPays) external;
}
