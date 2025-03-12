// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../SaltRewards.sol";


contract TestSaltRewards is SaltRewards
    {
    constructor( IExchangeConfig _exchangeConfig, IRewardsConfig _rewardsConfig )
    SaltRewards( _exchangeConfig, _rewardsConfig )
		{
		}


	function setPendingRewardsSaltUSDS(uint256 amount) public
		{
		pendingRewardsSaltUSDS = amount;
		}


	function setPendingStakingRewards(uint256 amount) public
		{
		pendingStakingRewards = amount;
		}


	function setPendingLiquidityRewards(uint256 amount) public
		{
		pendingLiquidityRewards = amount;
		}


	// Send the pending SALT rewards to the stakingRewardsEmitter
	function sendStakingRewards() public
		{
		_sendStakingRewards();
		}


	// Transfer SALT rewards to the liquidityRewardsEmitter proportional to pool shares in generating recent arb profits.
	function sendLiquidityRewards( bytes32[] memory poolIDs, uint256[] memory profitsForPools ) public
		{
		_sendLiquidityRewards( poolIDs, profitsForPools );
		}


	function sendInitialLiquidityRewards( uint256 liquidityBootstrapAmount, bytes32[] memory poolIDs ) public
		{
		_sendInitialLiquidityRewards( liquidityBootstrapAmount, poolIDs );
		}


	function sendInitialStakingRewards( uint256 stakingBootstrapAmount ) public
		{
		_sendInitialStakingRewards(stakingBootstrapAmount);
		}
	}
