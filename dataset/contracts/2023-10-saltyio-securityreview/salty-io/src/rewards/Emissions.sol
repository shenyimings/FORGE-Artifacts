// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../interfaces/ISalt.sol";
import "../interfaces/IExchangeConfig.sol";
import "./interfaces/IEmissions.sol";
import "../rewards/interfaces/IRewardsConfig.sol";


// Responsible for storing the SALT emissions at launch and then distributing them over time.
// The emissions are gradually distributed to the stakingRewardsEmitter and liquidityRewardsEmitter on performUpkeep (via the SaltRewards contract).
// Default rate of emissions is 0.50% of the remaining SALT balance per week (interpolated based on the time elapsed since the last performUpkeep call).

contract Emissions is IEmissions
    {
    uint256 constant public MAX_TIME_SINCE_LAST_UPKEEP = 1 weeks;

    ISaltRewards immutable public saltRewards;
	IExchangeConfig immutable public exchangeConfig;
	IRewardsConfig immutable public rewardsConfig;
	ISalt immutable public salt;


    constructor( ISaltRewards _saltRewards, IExchangeConfig _exchangeConfig, IRewardsConfig _rewardsConfig )
		{
		require( address(_saltRewards) != address(0), "_saltRewards cannot be address(0)" );
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );
		require( address(_rewardsConfig) != address(0), "_rewardsConfig cannot be address(0)" );

		saltRewards = _saltRewards;
		exchangeConfig = _exchangeConfig;
		rewardsConfig = _rewardsConfig;

		// Cached for efficiency
		salt = _exchangeConfig.salt();
		}


	// Transfer a percent (default 0.50% per week) of the currently held SALT to the stakingRewardsEmitter and liquidityRewardsEmitter (via SaltRewards).
	// The percentage to transfer is interpolated from how long it's been since the last performUpkeep() call.
	function performUpkeep(uint256 timeSinceLastUpkeep) public
		{
		require( msg.sender == address(exchangeConfig.upkeep()), "Emissions.performUpkeep is only callable from the Upkeep contract" );

		if ( timeSinceLastUpkeep == 0 )
			return;

		// Cap the timeSinceLastUpkeep at one week (if for some reason it has been longer).
		// This will cap the emitted rewards at a default of 0.50% in this transaction.
		if ( timeSinceLastUpkeep >= MAX_TIME_SINCE_LAST_UPKEEP )
			timeSinceLastUpkeep = MAX_TIME_SINCE_LAST_UPKEEP;

		uint256 saltBalance = salt.balanceOf( address( this ) );

		// Target a certain percentage of rewards per week and base what we need to distribute now on how long it has been since the last distribution
		uint256 saltToSend = ( saltBalance * timeSinceLastUpkeep * rewardsConfig.emissionsWeeklyPercentTimes1000() ) / ( 100 * 1000 weeks );
		if ( saltToSend == 0 )
			return;

		salt.approve( address(saltRewards), saltToSend );
		saltRewards.addSALTRewards(saltToSend);
		}
	}
