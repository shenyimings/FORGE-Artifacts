// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


enum Vote { INCREASE, DECREASE, NO_CHANGE, YES, NO }
enum BallotType { PARAMETER, WHITELIST_TOKEN, UNWHITELIST_TOKEN, SEND_SALT, CALL_CONTRACT, INCLUDE_COUNTRY, EXCLUDE_COUNTRY, SET_CONTRACT, SET_WEBSITE_URL, CONFIRM_SET_CONTRACT, CONFIRM_SET_WEBSITE_URL }

struct UserVote
	{
	Vote vote;
	uint256 votingPower;				// Voting power at the time the vote was cast
	}

struct Ballot
	{
	uint256 ballotID;
	bool ballotIsLive;

	BallotType ballotType;
	string ballotName;
	address address1;
	uint256 number1;
	string string1;
	string description;

	// The earliest timestamp at which a ballot can end. Can be open longer if the quorum has not yet been reached for instance.
	uint256 ballotMinimumEndTime;
	}


interface IProposals
	{
	function createConfirmationProposal( string calldata ballotName, BallotType ballotType, address address1, string calldata string1, string calldata description ) external;
	function markBallotAsFinalized( uint256 ballotID ) external;

	function proposeParameterBallot( uint256 parameterType, string calldata description ) external;
	function proposeTokenWhitelisting( IERC20 token, string calldata tokenIconURL, string calldata description ) external;
	function proposeTokenUnwhitelisting( IERC20 token, string calldata tokenIconURL, string calldata description ) external;
	function proposeSendSALT( address wallet, uint256 amount, string calldata description ) external;
	function proposeCallContract( address contractAddress, uint256 number, string calldata description ) external;
	function proposeCountryInclusion( string calldata country, string calldata description ) external;
	function proposeCountryExclusion( string calldata country, string calldata description ) external;
	function proposeSetContractAddress( string calldata contractName, address newAddress, string calldata description ) external;
	function proposeWebsiteUpdate( string calldata newWebsiteURL, string calldata description ) external;

	function castVote( uint256 ballotID, Vote vote ) external;

	// Views
	function nextBallotID() external returns (uint256);
	function openBallotsByName( string calldata name ) external returns (uint256);

	function ballotForID( uint256 ballotID ) external view returns (Ballot calldata);
	function lastUserVoteForBallot( uint256 ballotID, address user ) external view returns (UserVote calldata);
	function votesCastForBallot( uint256 ballotID, Vote vote ) external view returns (uint256);
	function requiredQuorumForBallotType( BallotType ballotType ) external view returns (uint256 requiredQuorum);
	function totalVotesCastForBallot( uint256 ballotID ) external view returns (uint256);
	function ballotIsApproved( uint256 ballotID ) external view returns (bool);
	function winningParameterVote( uint256 ballotID ) external view returns (Vote);
	function canFinalizeBallot( uint256 ballotID ) external view returns (bool);
	function numberOfOpenBallots() external view returns (uint256);
	function openBallots() external view returns (uint256[] memory);
	function numberOfOpenBallotsForTokenWhitelisting() external view returns (uint256);
	function openBallotsForTokenWhitelisting() external view returns (uint256[] memory);
	function tokenWhitelistingBallotWithTheMostVotes() external view returns (uint256);
	}