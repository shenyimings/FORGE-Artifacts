// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./StakingRewards.sol";
import "../interfaces/ISalt.sol";
import "./interfaces/IStaking.sol";
import "../pools/PoolUtils.sol";


// Staking SALT provides xSALT at a 1:1 ratio.
// Unstaking xSALT to reclaim SALT has a default unstake duration of 52 weeks and a minimum duration of two weeks.
// By default, unstaking for two weeks allows 20% of the SALT to be reclaimed, while unstaking for the full six months allows the full 100%

contract Staking is IStaking, StakingRewards
    {
	using SafeERC20 for ISalt;


	// The unstakeIDs for each user
	mapping(address => uint256[]) private _userUnstakeIDs;

	// Mapping of unstake IDs to their corresponding Unstake data.
    mapping(uint256=>Unstake) private _unstakesByID;
	uint256 public nextUnstakeID;


	constructor( IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IStakingConfig _stakingConfig )
		StakingRewards( _exchangeConfig, _poolsConfig, _stakingConfig )
		{
		}


	// Stake a given amount of SALT and immediately receive the same amount of xSALT
	// Requires exchange access for the sending wallet
	function stakeSALT( uint256 amountToStake ) public nonReentrant
		{
		require( exchangeConfig.walletHasAccess(msg.sender), "Sender does not have exchange access" );

		// The SALT will be converted instantly to xSALT

		// Increase the user's staking share so that they will receive more future SALT rewards
		// No cooldown as it takes default 52 weeks to unstake the xSALT to receive the full amount staked SALT back
		_increaseUserShare( msg.sender, PoolUtils.STAKED_SALT, amountToStake, false );

		// Transfer the SALT from the user's wallet
		salt.safeTransferFrom( msg.sender, address(this), amountToStake );
		}


	// Unstake a given amount of xSALT over a certain duration.
	function unstake( uint256 amountUnstaked, uint256 numWeeks ) public nonReentrant returns (uint256 unstakeID)
		{
		require( msg.sender != address(exchangeConfig.dao()), "DAO cannot unstake" );

		uint256 claimableSALT = calculateUnstake( amountUnstaked, numWeeks );
		uint256 completionTime = block.timestamp + numWeeks * ( 1 weeks );

		Unstake memory u = Unstake( UnstakeState.PENDING, msg.sender, amountUnstaked, claimableSALT, completionTime );
		unstakeID = nextUnstakeID++;

		_unstakesByID[unstakeID] = u;
		_userUnstakeIDs[msg.sender].push( unstakeID );

		// Unstaking immediately reduces the user's xSALT balance even though there will be the specified delay to convert it back to SALT

		// Decrease the user's staking share so that they will receive less future SALT rewards
		// This call will send any pending SALT rewards to msg.sender as well.
		// Note: _decreaseUserShare checks to make sure that the user has the specified staking share balance.
		_decreaseUserShare( msg.sender, PoolUtils.STAKED_SALT, amountUnstaked, false );
		}


	// Cancel a pending unstake.
	function cancelUnstake( uint256 unstakeID ) public nonReentrant
		{
		Unstake storage u = _unstakesByID[unstakeID];

		require( u.status == UnstakeState.PENDING, "Only PENDING unstakes can be cancelled" );
		require( block.timestamp < u.completionTime, "Unstakes that have already completed cannot be cancelled" );
		require( msg.sender == u.wallet, "Not the original staker" );

		// User will be able to use the xSALT again immediately

		// Update the user's share of the rewards for staked SALT
		_increaseUserShare( msg.sender, PoolUtils.STAKED_SALT, u.unstakedXSALT, false );

		u.status = UnstakeState.CANCELLED;
		}


	// Recover claimable SALT from a completed unstake
	function recoverSALT( uint256 unstakeID ) public nonReentrant
		{
		Unstake storage u = _unstakesByID[unstakeID];
		require( u.status == UnstakeState.PENDING, "Only PENDING unstakes can be claimed" );
		require( block.timestamp >= u.completionTime, "Unstake has not completed yet" );
		require( msg.sender == u.wallet, "Not the original staker" );

		u.status = UnstakeState.CLAIMED;

		// See if the user unstaked early and received only a portion of their original stake
		// The portion they did not receive will be considered the earlyUnstakeFee
		uint256 earlyUnstakeFee = u.unstakedXSALT - u.claimableSALT;

		// Burn 100% of the earlyUnstakeFee
		if ( earlyUnstakeFee > 0 )
			{
			// Send the earlyUnstakeFee to the SALT contract and burn it
			salt.safeTransfer( address(salt), earlyUnstakeFee );
            salt.burnTokensInContract();
            }

		// Send the reclaimed SALT back to the user
		salt.safeTransfer( msg.sender, u.claimableSALT );
		}


	// Send xSALT from the Airdrop contract to a user
	function transferXSaltFromAirdrop(address wallet, uint256 amountToTransfer) public
		{
		require( msg.sender == address(exchangeConfig.airdrop()), "Staking.transferXSaltFromAirdrop is only callable from the Airdrop contract" );

		_decreaseUserShare( msg.sender, PoolUtils.STAKED_SALT, amountToTransfer, false );
		_increaseUserShare( wallet, PoolUtils.STAKED_SALT, amountToTransfer, false );
		}


	// === VIEWS ===


	function userXSalt( address wallet ) external view returns (uint256)
		{
		return userShareForPool(wallet, PoolUtils.STAKED_SALT);
		}


	// Retrieve all pending unstakes associated with a user within a specific range.
	function unstakesForUser( address user, uint256 start, uint256 end ) public view returns (Unstake[] memory) {
        // Check if start and end are within the bounds of the array
        require(end >= start, "Invalid range: end cannot be less than start");

        uint256[] memory userUnstakes = _userUnstakeIDs[user];

        require(userUnstakes.length > end, "Invalid range: end is out of bounds");
        require(start < userUnstakes.length, "Invalid range: start is out of bounds");

        Unstake[] memory unstakes = new Unstake[](end - start + 1);

        uint256 index;
        for(uint256 i = start; i <= end; i++)
            unstakes[index++] = _unstakesByID[ userUnstakes[i]];

        return unstakes;
    }


	// Retrieve all pending unstakes associated with a user.
	function unstakesForUser( address user ) external view returns (Unstake[] memory)
		{
		// Check to see how many unstakes the user has
		uint256[] memory unstakeIDs = _userUnstakeIDs[user];
		if ( unstakeIDs.length == 0 )
			return new Unstake[](0);

		// Return them all
		return unstakesForUser( user, 0, unstakeIDs.length - 1 );
		}


	// Returns the unstakeIDs for the user
	function userUnstakeIDs( address user ) public view returns (uint256[] memory)
		{
		return _userUnstakeIDs[user];
		}


	function unstakeByID(uint256 id) external view returns (Unstake memory)
		{
		return _unstakesByID[id];
		}


	// Calculate the reclaimable amount of SALT based on the amount of xSALT unstaked and unstake duration
	function calculateUnstake( uint256 unstakedXSALT, uint256 numWeeks ) public view returns (uint256)
		{
		uint256 minUnstakeWeeks = stakingConfig.minUnstakeWeeks();
        uint256 maxUnstakeWeeks = stakingConfig.maxUnstakeWeeks();
        uint256 minUnstakePercent = stakingConfig.minUnstakePercent();

		require( numWeeks >= minUnstakeWeeks, "Unstaking duration too short" );
		require( numWeeks <= maxUnstakeWeeks, "Unstaking duration too long" );

		uint256 percentAboveMinimum = 100 - minUnstakePercent;
		uint256 unstakeRange = maxUnstakeWeeks - minUnstakeWeeks;

		uint256 numerator = unstakedXSALT * ( minUnstakePercent * unstakeRange + percentAboveMinimum * ( numWeeks - minUnstakeWeeks ) );
    	return numerator / ( 100 * unstakeRange );
		}
	}