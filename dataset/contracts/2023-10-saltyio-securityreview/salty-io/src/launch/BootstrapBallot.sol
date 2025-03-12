// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "./interfaces/IBootstrapBallot.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IAirdrop.sol";
import "../interfaces/IExchangeConfig.sol";
import "../SigningTools.sol";


// Allows airdrop participants to vote on whether or not to start up the exchange and which countries should be initially excluded from access.

contract BootstrapBallot is IBootstrapBallot, ReentrancyGuard
    {
    IExchangeConfig public exchangeConfig;
    IAirdrop public airdrop;

	uint256 public completionTimestamp;
	bool public ballotFinalized;
	bool private _startExchangeApproved;

	// Ensures that voters can only vote once
	mapping(address=>bool) public hasVoted;

	// === VOTE TALLIES ===
	// Yes/No tallies on whether or not to start the exchange and distribute SALT to the ecosystem contracts
	uint256 public startExchangeYes;
	uint256 public startExchangeNo;

	// Yes/No tallies on whether or not to exclude specified countries/regions
	uint256[] private _geoExclusionYes = new uint256[](5);
	uint256[] private _geoExclusionNo = new uint256[](5);


	constructor( IExchangeConfig _exchangeConfig, IAirdrop _airdrop, uint256 ballotDuration )
		{
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );
		require( address(_airdrop) != address(0), "_airdrop cannot be address(0)" );
		require( ballotDuration > 0, "ballotDuration cannot be zero" );

		exchangeConfig = _exchangeConfig;
		airdrop = _airdrop;

		completionTimestamp = block.timestamp + ballotDuration;
		}


	// Cast a YES or NO vote to start up the exchange, distribute SALT and establish initial geo restrictions (airdropped users only).
	// votesRegionalExclusions: 0 (no opinion), 1 (yes to exclusion), 2 (no to exclusion)
	// Votes cannot be changed once they are cast.
	// Requires a valid signature to signify that the msg.sender is authorized to vote (being whitelisted and the retweeting exchange launch posting - checked offchain)
	function vote( bool voteStartExchangeYes, uint256[] memory votesRegionalExclusions, bytes memory signature ) public nonReentrant
		{
		require( votesRegionalExclusions.length == 5, "Incorrect length for votesRegionalExclusions" );
		require( ! hasVoted[msg.sender], "User already voted" );

		// Verify the signature to confirm the user is authorized to vote
		bytes32 messageHash = keccak256(abi.encodePacked(msg.sender));
		require(SigningTools._verifySignature(messageHash, signature), "Incorrect BootstrapBallot.vote signatory" );

		if ( voteStartExchangeYes )
			startExchangeYes++;
		else
			startExchangeNo++;

		for( uint256 i = 0; i < 5; i++ )
			{
			if ( votesRegionalExclusions[i] == 1 )
				_geoExclusionYes[i]++;

			if ( votesRegionalExclusions[i] == 2 )
				_geoExclusionNo[i]++;
			}

		hasVoted[msg.sender] = true;

		// As the whitelisted user has retweeted the launch message and voted, they are authorized to the receive the airdrop
		airdrop.authorizeWallet(msg.sender);
		}


	// Ensures that the completionTimestamp has been reached and then calls InitialDistribution.distributionApproved and DAO.initialGeoExclusion if the voters have approved the ballot
	function finalizeBallot() public nonReentrant
		{
		require( ! ballotFinalized, "Ballot has already been finalized" );
		require( block.timestamp >= completionTimestamp, "Ballot is not yet complete" );

		if ( startExchangeYes > startExchangeNo )
			{
			exchangeConfig.initialDistribution().distributionApproved();
			exchangeConfig.dao().initialGeoExclusion(_geoExclusionYes, _geoExclusionNo);

			_startExchangeApproved = true;
			}

		ballotFinalized = true;
		}


	// === VIEWS ===
	function startExchangeApproved() public virtual returns (bool)
		{
		return _startExchangeApproved;
		}


	function geoExclusionYes() public view returns (uint256[] memory)
		{
		return _geoExclusionYes;
		}


	function geoExclusionNo() public view returns (uint256[] memory)
		{
		return _geoExclusionNo;
		}
	}