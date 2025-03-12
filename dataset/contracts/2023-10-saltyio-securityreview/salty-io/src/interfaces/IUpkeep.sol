// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;


interface IUpkeep
	{
	function performUpkeep() external;

	// Views
	function lastUpkeepTime() external returns (uint256);
	function currentRewardsForCallingPerformUpkeep() external returns (uint256);
	}
