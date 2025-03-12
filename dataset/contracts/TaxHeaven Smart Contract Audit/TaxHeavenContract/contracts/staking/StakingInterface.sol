// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.1;

interface StakingInterface {
    function stake(address token, uint128 amount) external;

    function withdraw(address token, uint128 amount) external;

    function receiveReward(address token) external returns (uint256 rewards);

    function changeStakeTarget(
        address oldTarget,
        address newTarget,
        uint128 amount
    ) external;

    function getStakingTokenAddress() external view returns (address);

    function getTokenInfo(address token)
        external
        view
        returns (
            uint256 currentTerm,
            uint256 latestTerm,
            uint256 totalRemainingRewards,
            uint256 currentReward,
            uint256 nextTermRewards,
            uint128 currentStaking,
            uint128 nextTermStaking
        );

    function getConfigs() external view returns (uint256 startTimestamp, uint256 termInterval);

    function getStakingDestinations(address account) external view returns (address[] memory);

    function getTermInfo(address token, uint256 term)
        external
        view
        returns (
            uint128 stakeAdd,
            uint128 stakeSum,
            uint256 rewardSum
        );

    function getAccountInfo(address token, address account)
        external
        view
        returns (
            uint256 userTerm,
            uint256 stakeAmount,
            uint128 nextAddedStakeAmount,
            uint256 currentReward,
            uint256 nextLatestTermUserRewards,
            uint128 depositAmount,
            uint128 withdrawableStakingAmount
        );
}
