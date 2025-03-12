// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
pragma experimental ABIEncoderV2;

/**
 * @dev Interface for AutoFarm.
 */
interface IAutoFarm {

    // Info of each user.
    struct UserInfo {
        uint256 shares; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.

        // We do some fancy math here. Basically, any point in time, the amount of AUTO
        // entitled to a user but is pending to be distributed is:
        //
        //   amount = user.shares / sharesTotal * wantLockedTotal
        //   pending reward = (amount * pool.accAUTOPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws want tokens to a pool. Here's what happens:
        //   1. The pool's `accAUTOPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    /**
     * @dev View function to see pending AUTO on frontend.
     */ 
    function pendingAUTO(uint256 _pid, address _user) external view returns (uint256);

    /**
     * @dev View function to see staked Want tokens on frontend.
     */
    function stakedWantTokens(uint256 _pid, address _user) external view returns (uint256);

    function userInfo(uint256 _pid, address _user) external view returns (UserInfo memory);

    /**
     * @dev Want tokens moved from user -> AUTOFarm (AUTO allocation) -> Strat (compounding)
     */ 
    function deposit(uint256 _pid, uint256 _amount) external;

    /**
     * @dev Withdraw LP tokens from MasterChef.
     */
    function withdraw(uint256 _pid, uint256 _amount) external;
}