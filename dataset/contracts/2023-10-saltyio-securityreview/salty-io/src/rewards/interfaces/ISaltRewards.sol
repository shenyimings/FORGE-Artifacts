// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;


interface ISaltRewards
	{
	function addSALTRewards(uint256 amount) external;
	function sendInitialSaltRewards( uint256 liquidityBootstrapAmount, bytes32[] memory poolIDs ) external;
    function performUpkeep( bytes32[] calldata poolIDs, uint256[] calldata profitsForPools ) external;

    // Views
    function pendingRewardsSaltUSDS() external returns (uint256);
    function pendingStakingRewards() external returns (uint256);
    function pendingLiquidityRewards() external returns (uint256);
    }