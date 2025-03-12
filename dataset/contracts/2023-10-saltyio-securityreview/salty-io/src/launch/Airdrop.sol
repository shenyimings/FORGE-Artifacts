// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "./interfaces/IAirdrop.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IExchangeConfig.sol";
import "../staking/interfaces/IStaking.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";


// The Airdrop contract keeps track of users who qualify for the Salty.IO Airdrop (participants of prominent DeFi protocols who perform a basic social media task and vote).
// The airdrop participants are able to claim staked SALT after the airdrop authorization period has ending (after the BootingstappingBallot has concluded).
contract Airdrop is IAirdrop, ReentrancyGuard
    {
    using EnumerableSet for EnumerableSet.AddressSet;

	IExchangeConfig public exchangeConfig;
    IStaking public staking;
    ISalt public salt;

	// These are authorized users who have retweeted the launch announcement and voted and have been authorized to receive the airdrop
	EnumerableSet.AddressSet private _authorizedUsers;

	bool public claimingAllowed;
	mapping(address=>bool) public claimed;

	uint256 public saltAmountForEachUser;


	constructor( IExchangeConfig _exchangeConfig, IStaking _staking )
		{
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );
		require( address(_staking) != address(0), "_staking cannot be address(0)" );

		exchangeConfig = _exchangeConfig;
		staking = _staking;

		salt = _exchangeConfig.salt();
		}


	// Authorize the wallet as being able to claim the airdrop.
    function authorizeWallet( address wallet ) public
    	{
    	require( msg.sender == address(exchangeConfig.initialDistribution().bootstrapBallot()), "Only the BootstrapBallot can call Airdrop.authorizeWallet" );
    	require( ! claimingAllowed, "Cannot authorize after claiming is allowed" );

		_authorizedUsers.add(wallet);
    	}


	// Called by the InitialDistribution contract during its distributionApproved() function - which is called on successful conclusion of the BootstrappingBallot
    function allowClaiming() public
    	{
    	require( msg.sender == address(exchangeConfig.initialDistribution()), "Airdrop.allowClaiming can only be called by the InitialDistribution contract" );
    	require( ! claimingAllowed, "Claiming is already allowed" );
		require(numberAuthorized() > 0, "No addresses authorized to claim airdrop.");

    	// All users receive an equal share of the airdrop
		saltAmountForEachUser = salt.balanceOf(address(this)) / numberAuthorized();

		// Have the Airdrop contract stake all of the SALT that it holds so that that xSALT (staked SALT) can later be transferred to airdrop recipients
		salt.approve( address(staking), type(uint256).max );

    	claimingAllowed = true;
    	}


	// Sends a fixed amount of xSALT (staked SALT) to a qualifying user
    function claimAirdrop() public nonReentrant
    	{
    	require( claimingAllowed, "Claiming is not allowed yet" );
    	require( isAuthorized(msg.sender), "Wallet is not authorized for airdrop" );
    	require( ! claimed[msg.sender], "Wallet already claimed the airdrop" );

		// Have the Airdrop contract stake a specified amount of SALT and then transfer it to the user
		staking.stakeSALT( saltAmountForEachUser );
		staking.transferXSaltFromAirdrop( msg.sender, saltAmountForEachUser );

    	claimed[msg.sender] = true;
    	}


    // === VIEWS ===
    // Returns true if the specified wallet has been authorized
    function isAuthorized(address wallet) public view returns (bool)
    	{
    	return _authorizedUsers.contains(wallet);
    	}


	// The current number of authorized wallets
    function numberAuthorized() public view returns (uint256)
    	{
    	return _authorizedUsers.length();
    	}


	// Returns an array of the currently authorized wallets
	function authorizedWallets() public view returns (address[] memory)
		{
		return _authorizedUsers.values();
		}
	}