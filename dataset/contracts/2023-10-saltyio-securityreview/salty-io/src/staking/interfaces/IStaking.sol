// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "./IStakingRewards.sol";


// Enum representing the possible states of an unstake request:
// NONE: The default state, indicating that no unstake request has been made.
// PENDING: The state indicating that an unstake request has been made, but has not yet completed.
// CANCELLED: The state indicating that a pending unstake request has been cancelled by the user.
// CLAIMED: The state indicating that a pending unstake request has been completed and the user can claim their SALT tokens.
enum UnstakeState { NONE, PENDING, CANCELLED, CLAIMED }

 struct Unstake
	{
	UnstakeState status;			// see above

	address wallet;					// the wallet of the user performing the unstake
	uint256 unstakedXSALT;		// the amount of xSALT that was unstaked
	uint256 claimableSALT;		// claimable SALT at completion time
	uint256 completionTime;		// the timestamp when the unstake completes
	}


interface IStaking is IStakingRewards
	{
	function stakeSALT( uint256 amountToStake ) external;
	function unstake( uint256 amountUnstaked, uint256 numWeeks ) external returns (uint256 unstakeID);
	function cancelUnstake( uint256 unstakeID ) external;
	function recoverSALT( uint256 unstakeID ) external;
	function transferXSaltFromAirdrop(address wallet, uint256 amount) external;

	// Views
	function userXSalt( address wallet ) external view returns (uint256);
	function unstakesForUser( address wallet, uint256 start, uint256 end ) external view returns (Unstake[] calldata);
	function unstakesForUser( address wallet ) external view returns (Unstake[] calldata);
	function userUnstakeIDs( address user ) external view returns (uint256[] calldata);
	function unstakeByID(uint256 id) external view returns (Unstake calldata);
	function calculateUnstake( uint256 unstakedXSALT, uint256 numWeeks ) external view returns (uint256);
	}
