//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

interface IReward {
    struct Lender {
        uint16 round;
        uint40 startPeriod;
        uint pendingRewards;
        uint deposit;
        bool registered;
    }

    struct RoundInfo {
        uint16 apy;
        uint40 startTime;
        uint40 endTime;
    }

    /**
     * @notice Emitted after `reward` is updated by OWNER.
     * @param oldReward, value of the old reward.
     * @param newReward, value of the new reward.
     */
    event NewReward(uint16 oldReward, uint16 newReward);

    /**
     * @notice Emitted after Reward is transferred to user.
     * @param lender, address of the lender.
     * @param amount, amount transferred to lender.
     */
    event RewardClaimed(address lender, uint amount);

    function registerUser(
        address lender,
        uint deposited,
        uint40 startPeriod
    ) external;

    /**
     * @notice `deposit` increases the `lender` deposit by `amount`
     * @dev It can be called by only REWARD_MANAGER.
     * @param lender, address of the lender
     * @param amount, amount deposited by lender
     *
     * Requirements:
     * - `amount` should be greater than 0
     *
     */
    function deposit(address lender, uint amount) external;

    /**
     * @notice `withdraw` withdraws the `amount` from `lender`
     * @dev It can be called by only REWARD_MANAGER.
     * @param lender, address of the lender
     * @param amount, amount requested by lender
     *
     * - `amount` should be greater than 0
     * - `amount` should be greater than deposited by the lender
     *
     */
    function withdraw(address lender, uint amount) external;

    /**
     * @notice `claimReward` send reward to lender.
     * @dev It calls `_updatePendingReward` function and sets pending reward to 0.
     * @dev It can be called by only REWARD_MANAGER.
     * @param lender, address of the lender.
     *
     * Emits {RewardClaimed} event
     */
    function claimReward(address lender) external;

    /**
     * @notice `setReward` updates the value of reward.
     * @dev For example - APY in case of tStable, trade per year per stable in case of trade reward.
     * @dev It can be called by only OWNER.
     * @param newReward, current reward offered by the contract.
     *
     * Emits {NewReward} event
     */
    function setReward(uint16 newReward) external;

    /**
     * @notice `pauseReward` sets the apy to 0.
     * @dev It is called after `RewardManager` is discontinued.
     * @dev It can be called by only REWARD_MANAGER.
     *
     * Emits {NewReward} event
     */
    function resetReward() external;

    /**
     * @notice `rewardOf` returns the total pending reward of the lender
     * @dev It calculates reward of lender upto current time.
     * @param lender, address of the lender
     * @return returns the total pending reward
     */
    function rewardOf(address lender) external view returns (uint);

    /**
     * @notice `getReward` returns the total reward.
     * @return returns the total reward.
     */
    function getReward() external view returns (uint16);

    /**
     * @notice `getRewardToken` returns the address of the reward token
     * @return address of the reward token
     */
    function getRewardToken() external view returns (address);
}
