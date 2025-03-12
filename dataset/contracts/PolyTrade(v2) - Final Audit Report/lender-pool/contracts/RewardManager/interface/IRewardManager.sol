//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

interface IRewardManager {
    struct Lender {
        uint deposit;
        bool registered;
    }

    /**
     * @notice Emitted when RewardManger has started
     * @dev Emitted when RewardManger has started (can be called only by owner)
     * @param startTime, starting time (timestamp)
     */
    event RewardManagerStarted(uint40 startTime);

    /**
     * @notice `startRewardManager` registers the `RewardManager`
     * @dev It can be called by LENDER_POOL only
     */
    function startRewardManager() external;

    /**
     * @notice `registerUser` registers the user to the current `RewardManager`
     * @dev It copies the user information from previous `RewardManager`.
     * @param lender, address of the lender
     */
    function registerUser(address lender) external;

    /**
     * @notice `claimRewardsFor` claims reward for the lender.
     * @dev All the reward are transferred to the lender.
     * @dev It can by only called by `LenderPool`.
     * @param lender, address of the lender
     */
    function claimAllRewardsFor(address lender) external;

    /**
     * @notice `increaseDeposit` increases the amount deposited by lender.
     * @dev It calls the `deposit` function of all the rewards in `RewardManager`.
     * @dev It can by only called by `LenderPool`.
     * @param lender, address of the lender
     * @param amount, amount deposited by the lender
     */
    function increaseDeposit(address lender, uint amount) external;

    /**
     * @notice `withdrawDeposit` decrease the amount deposited by the lender.
     * @dev It calls the `withdraw` function of all the rewards in `RewardManager`
     * @dev It can by only called by `LenderPool`.
     * @param lender, address of the lender
     * @param amount, amount withdrawn by the lender
     */
    function withdrawDeposit(address lender, uint amount) external;

    /**
     * @notice `resetRewards` sets the reward for all the tokens to 0
     */
    function resetRewards() external;

    /**
     * @notice `claimRewardFor` transfer all the `token` reward to the `user`
     * @dev It can be called by LENDER_POOL only.
     * @param lender, address of the lender
     * @param token, address of the token
     */
    function claimRewardFor(address lender, address token) external;

    /**
     * @notice `rewardOf` returns array of reward for the lender
     * @dev It returns array of number, where each element is a reward
     * @dev For example - [stable reward, trade reward 1, trade reward 2]
     */
    function rewardOf(address lender, address token)
        external
        view
        returns (uint);

    /**
     * @notice `getDeposit` returns the total amount deposited by the lender
     * @dev If this RewardManager is not the current and user has registered then this value will not be updated
     * @param lender, address of the lender
     * @return total amount deposited by the lender
     */
    function getDeposit(address lender) external view returns (uint);
}
