// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStakingRewards {
    /// VIEWS
    // token state
    function totalSupply() external view returns (uint256);
    // staking state
    function balanceOf(address account) external view returns (uint256);
    function escrowedBalanceOf(address account) external view returns (uint256);
    function nonEscrowedBalanceOf(address account) external view returns (uint256);
    // rewards
    function getRewardForDuration() external view returns (uint256);
    function rewardPerToken() external view returns (uint256);
    function lastTimeRewardApplicable() external view returns (uint256);
    function earned(address account) external view returns (uint256);

    /// MUTATIVE
    // Staking/Unstaking
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function stakeEscrow(address account, uint256 amount) external;
    function unstakeEscrow(address account, uint256 amount) external;
    function exit() external;
    // claim rewards
    function getReward() external;
    // settings
    function notifyRewardAmount(uint256 reward) external;
    function setRewardsDuration(uint256 _rewardsDuration) external;
    // pausable
    function pauseStakingRewards() external;
    function unpauseStakingRewards() external;
    // misc.
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external;
}
