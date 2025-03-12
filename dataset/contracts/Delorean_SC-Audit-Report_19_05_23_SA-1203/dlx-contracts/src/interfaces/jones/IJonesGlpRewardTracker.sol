// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { IJonesGlpRewardDistributor } from "./IJonesGlpRewardDistributor.sol";

interface IJonesGlpRewardTracker {
    /* mapping(address => uint256) public stakedAmounts; */
    function stakedAmounts(address) external view returns (uint256);
    function claimableReward(address) external view returns (uint256);

    function distributor() external view returns (IJonesGlpRewardDistributor);

    event Stake(address indexed depositor, uint256 amount);
    event Withdraw(address indexed _account, uint256 _amount);
    event Claim(address indexed receiver, uint256 amount);
    event UpdateRewards(address indexed _account, uint256 _rewards, uint256 _totalShares, uint256 _rewardPerShare);

    /**
     * @notice Stake into this contract assets to start earning rewards
     * @param _account Owner of the stake and future rewards
     * @param _amount Assets to be staked
     * @return Amount of assets staked
     */
    function stake(address _account, uint256 _amount) external returns (uint256);

    /**
     * @notice Withdraw the staked assets
     * @param _account Owner of the assets to be withdrawn
     * @param _amount Assets to be withdrawn
     * @return Amount of assets witdrawed
     */
    function withdraw(address _account, uint256 _amount) external returns (uint256);

    /**
     * @notice Claim _account cumulative rewards
     * @dev Reward token will be transfer to the _account
     * @param _account Owner of the rewards
     * @return Amount of reward tokens transferred
     */
    function claim(address _account) external returns (uint256);

    /**
     * @notice Return _account claimable rewards
     * @dev No reward token are transferred
     * @param _account Owner of the rewards
     * @return Amount of reward tokens that can be claim
     */
    function claimable(address _account) external view returns (uint256);

    /**
     * @notice Return _account staked amount
     * @param _account Owner of the staking
     * @return Staked amount
     */
    function stakedAmount(address _account) external view returns (uint256);

    /**
     * @notice Update global cumulative reward
     * @dev No reward token are transferred
     */
    function updateRewards() external;

    /**
     * @notice Deposit rewards
     * @dev Transfer from called here
     * @param _rewards Amount of reward asset transferer
     */
    function depositRewards(uint256 _rewards) external;

    error AddressCannotBeZeroAddress();
    error AmountCannotBeZero();
    error AmountExceedsStakedAmount();
}
