// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;


interface IStakingConfig
	{
	function changeMinUnstakeWeeks(bool increase) external; // onlyOwner
	function changeMaxUnstakeWeeks(bool increase) external; // onlyOwner
	function changeMinUnstakePercent(bool increase) external; // onlyOwner
	function changeModificationCooldown(bool increase) external; // onlyOwner

	// Views
    function minUnstakeWeeks() external view returns (uint256);
    function maxUnstakeWeeks() external view returns (uint256);
    function minUnstakePercent() external view returns (uint256);
    function modificationCooldown() external view returns (uint256);
	}