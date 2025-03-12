// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;


interface IRewardsConfig
	{
	function changeRewardsEmitterDailyPercent(bool increase) external; // onlyOwner
	function changeEmissionsWeeklyPercent(bool increase) external; // onlyOwner
	function changeStakingRewardsPercent(bool increase) external; // onlyOwner
	function changePercentRewardsSaltUSDS(bool increase) external; // onlyOwner

	// Views
    function emissionsWeeklyPercentTimes1000() external view returns (uint256);
    function rewardsEmitterDailyPercentTimes1000() external view returns (uint256);
    function stakingRewardsPercent() external view returns (uint256);
    function percentRewardsSaltUSDS() external view returns (uint256);
    }