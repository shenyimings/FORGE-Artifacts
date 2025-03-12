// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/**
 * @dev Interface for Badger Geyser.
 */
interface IBadgerGeyser {

    /**
     * @param _addr The user to look up staking information for.
     * @return The number of staking tokens deposited for addr.
     */
    function totalStakedFor(address _addr) external view returns (uint256);

    /**
     * @dev Transfers amount of deposit tokens from the user.
     * @param _amount Number of deposit tokens to stake.
     */
    function stake(uint256 _amount, bytes calldata _data) external;

    /**
     * @dev Unstakes a certain amount of previously deposited tokens. User also receives their
     * alotted number of distribution tokens.
     * @param _amount Number of deposit tokens to unstake / withdraw.
     * @param _data Not used.
     */
    function unstake(uint256 _amount, bytes calldata _data) external;
}