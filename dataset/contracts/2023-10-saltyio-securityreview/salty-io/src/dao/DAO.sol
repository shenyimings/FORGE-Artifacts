// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../rewards/interfaces/IRewardsConfig.sol";
import "../stable/interfaces/IStableConfig.sol";
import "../staking/interfaces/ILiquidity.sol";
import "../staking/interfaces/IStaking.sol";
import "../rewards/interfaces/IRewardsEmitter.sol";
import "./interfaces/ICalledContract.sol";
import "../interfaces/IExchangeConfig.sol";
import "./interfaces/IProposals.sol";
import "../interfaces/IAccessManager.sol";
import "./interfaces/IDAO.sol";
import "../pools/PoolUtils.sol";
import "./Parameters.sol";
import "../price_feed/interfaces/IPriceAggregator.sol";
import "../Upkeep.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";


// Allows users to propose and vote on various governance actions such as changing parameters, whitelisting/unwhitelisting tokens, sending tokens, calling other contracts, and updating the website.
// It handles proposing ballots, tracking votes, enforcing voting requirements, and executing approved proposals.
contract DAO is IDAO, Parameters, ReentrancyGuard
    {
	using SafeERC20 for ISalt;
	using SafeERC20 for IERC20;

	IPools immutable public pools;
	IProposals immutable public proposals;
	IExchangeConfig immutable public exchangeConfig;
	IPoolsConfig immutable public poolsConfig;
	IStakingConfig immutable public stakingConfig;
	IRewardsConfig immutable public rewardsConfig;
	IStableConfig immutable public stableConfig;
	IDAOConfig immutable public daoConfig;
	IPriceAggregator immutable public priceAggregator;
	IRewardsEmitter immutable public liquidityRewardsEmitter;

	// The default IPFS URL for the website content (can be changed with a setWebsiteURL proposal)
	string public websiteURL;

	// Countries that have been excluded from access to the DEX (used by AccessManager.sol)
	mapping(string=>bool) public excludedCountries;


    constructor( IPools _pools, IProposals _proposals, IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IStakingConfig _stakingConfig, IRewardsConfig _rewardsConfig, IStableConfig _stableConfig, IDAOConfig _daoConfig, IPriceAggregator _priceAggregator, IRewardsEmitter _liquidityRewardsEmitter )
		{
		require( address(_pools) != address(0), "_pools cannot be address(0)" );
		require( address(_proposals) != address(0), "_proposals cannot be address(0)" );
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );
		require( address(_poolsConfig) != address(0), "_poolsConfig cannot be address(0)" );
		require( address(_stakingConfig) != address(0), "_stakingConfig cannot be address(0)" );
		require( address(_rewardsConfig) != address(0), "_rewardsConfig cannot be address(0)" );
		require( address(_stableConfig) != address(0), "_stableConfig cannot be address(0)" );
		require( address(_daoConfig) != address(0), "_daoConfig cannot be address(0)" );
		require( address(_priceAggregator) != address(0), "_priceAggregator cannot be address(0)" );
		require( address(_liquidityRewardsEmitter) != address(0), "_liquidityRewardsEmitter cannot be address(0)" );

		pools = _pools;
		proposals = _proposals;
		exchangeConfig = _exchangeConfig;
		poolsConfig = _poolsConfig;
		stakingConfig = _stakingConfig;
		rewardsConfig = _rewardsConfig;
		stableConfig = _stableConfig;
		daoConfig = _daoConfig;
		priceAggregator = _priceAggregator;
        liquidityRewardsEmitter = _liquidityRewardsEmitter;
        }


	// Finalize the vote for a parameter ballot (increase, decrease or no_change) for a given parameter
	function _finalizeParameterBallot( uint256 ballotID ) internal
		{
		Ballot memory ballot = proposals.ballotForID(ballotID);

		Vote winningVote = proposals.winningParameterVote(ballotID);

		if ( winningVote == Vote.INCREASE )
			_executeParameterChange( ParameterTypes(ballot.number1), true, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator );
		else if ( winningVote == Vote.DECREASE )
			_executeParameterChange( ParameterTypes(ballot.number1), false, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator );

		proposals.markBallotAsFinalized(ballotID);
		}


	function _executeSetContract( Ballot memory ballot ) internal
		{
		bytes32 nameHash = keccak256(bytes( ballot.ballotName ) );

		if ( nameHash == keccak256(bytes( "setContract:priceFeed1_confirm" )) )
			priceAggregator.setPriceFeed( 1, IPriceFeed(ballot.address1) );
		else if ( nameHash == keccak256(bytes( "setContract:priceFeed2_confirm" )) )
			priceAggregator.setPriceFeed( 2, IPriceFeed(ballot.address1) );
		else if ( nameHash == keccak256(bytes( "setContract:priceFeed3_confirm" )) )
			priceAggregator.setPriceFeed( 3, IPriceFeed(ballot.address1) );
		else if ( nameHash == keccak256(bytes( "setContract:accessManager_confirm" )) )
			exchangeConfig.setAccessManager( IAccessManager(ballot.address1) );
		else if ( nameHash == keccak256(bytes( "setContract:stakingRewardsEmitter_confirm" )) )
			exchangeConfig.setStakingRewardsEmitter( IRewardsEmitter(ballot.address1) );
		else if ( nameHash == keccak256(bytes( "setContract:liquidityRewardsEmitter_confirm" )) )
			exchangeConfig.setLiquidityRewardsEmitter( IRewardsEmitter(ballot.address1) );
		}


	function _executeSetWebsiteURL( Ballot memory ballot ) internal
		{
		websiteURL = ballot.string1;
		}


	function _executeApproval( Ballot memory ballot ) internal
		{
		if ( ballot.ballotType == BallotType.UNWHITELIST_TOKEN )
			{
			// All tokens are paired with both WBTC and WETH so unwhitelist those pools
			poolsConfig.unwhitelistPool(pools,  IERC20(ballot.address1), exchangeConfig.wbtc() );
			poolsConfig.unwhitelistPool(pools,  IERC20(ballot.address1), exchangeConfig.weth() );
			}

		else if ( ballot.ballotType == BallotType.SEND_SALT )
			{
			// Make sure the contract has the SALT balance before trying to send it
			// This should not happen but is here just in case - to prevent approved proposals from reverting on finalization
			if ( exchangeConfig.salt().balanceOf(address(this)) >= ballot.number1 )
				IERC20(exchangeConfig.salt()).safeTransfer( ballot.address1, ballot.number1 );
			}

		else if ( ballot.ballotType == BallotType.CALL_CONTRACT )
			ICalledContract(ballot.address1).callFromDAO( ballot.number1 );

		else if ( ballot.ballotType == BallotType.INCLUDE_COUNTRY )
			excludedCountries[ ballot.string1 ] = false;

		else if ( ballot.ballotType == BallotType.EXCLUDE_COUNTRY )
			{
			excludedCountries[ ballot.string1 ] = true;

			// If the AccessManager doesn't implement excludedCountriesUpdated, this will revert and countries will not be able to be excluded until the AccessManager is working properly.
			exchangeConfig.accessManager().excludedCountriesUpdated();
			}

		// Once an initial setContract proposal passes, it automatically starts a second confirmation ballot (to prevent last minute approvals)
		else if ( ballot.ballotType == BallotType.SET_CONTRACT )
			proposals.createConfirmationProposal( string.concat(ballot.ballotName, "_confirm"), BallotType.CONFIRM_SET_CONTRACT, ballot.address1, "", ballot.description );

		// Once an initial setWebsiteURL proposal passes, it automatically starts a second confirmation ballot (to prevent last minute approvals)
		else if ( ballot.ballotType == BallotType.SET_WEBSITE_URL )
			proposals.createConfirmationProposal( string.concat(ballot.ballotName, "_confirm"), BallotType.CONFIRM_SET_WEBSITE_URL, address(0), ballot.string1, ballot.description );

		else if ( ballot.ballotType == BallotType.CONFIRM_SET_CONTRACT )
			_executeSetContract( ballot );

		else if ( ballot.ballotType == BallotType.CONFIRM_SET_WEBSITE_URL )
			_executeSetWebsiteURL( ballot );
		}


	// Finalize the vote for an approval ballot (yes or no) for a given proposal
	function _finalizeApprovalBallot( uint256 ballotID ) internal
		{
		if ( proposals.ballotIsApproved(ballotID ) )
			{
			Ballot memory ballot = proposals.ballotForID(ballotID);
			_executeApproval( ballot );
			}

		proposals.markBallotAsFinalized(ballotID);
		}


	// Finalize and execute a token whitelisting ballot.
	// If the proposal is currently the whitelisting proposal with the most yes votes then the token can be whitelisted.
	// If NO > YES than the proposal is removed (quorum would already have been determined - in canFinalizeBallot as called from finalizeBallot).
	function _finalizeTokenWhitelisting( uint256 ballotID ) internal
		{
		if ( proposals.ballotIsApproved(ballotID ) )
			{
			Ballot memory ballot = proposals.ballotForID(ballotID);

			// Fail if we don't have enough rewards in the DAO for bootstrapping new tokens
			require( sufficientBootstrappingRewardsExistForWhitelisting(), "Whitelisting is not currently possible due to insufficient bootstrapping rewards" );

			// If yes is higher then fail to whitelist for now if this isn't the whitelisting proposal with the most votes
			uint256 bestWhitelistingBallotID = proposals.tokenWhitelistingBallotWithTheMostVotes();
			require( bestWhitelistingBallotID == ballotID, "Only the token whitelisting ballot with the most votes can be finalized" );

			// All tokens are paired with both WBTC and WETH, so whitelist both pairings
			poolsConfig.whitelistPool(pools,  IERC20(ballot.address1), exchangeConfig.wbtc() );
			poolsConfig.whitelistPool(pools,  IERC20(ballot.address1), exchangeConfig.weth() );

			(bytes32 pool1,) = PoolUtils._poolID( IERC20(ballot.address1), exchangeConfig.wbtc() );
			(bytes32 pool2,) = PoolUtils._poolID( IERC20(ballot.address1), exchangeConfig.weth() );


			uint256 bootstrappingRewards = daoConfig.bootstrappingRewards();

			// Send the initial bootstrappingRewards to promote initial liquidity on these two newly whitelisted pools
			AddedReward[] memory addedRewards = new AddedReward[](2);
			addedRewards[0] = AddedReward( pool1, bootstrappingRewards );
			addedRewards[1] = AddedReward( pool2, bootstrappingRewards );

			exchangeConfig.salt().approve( address(liquidityRewardsEmitter), bootstrappingRewards * 2 );
			liquidityRewardsEmitter.addSALTRewards( addedRewards );
			}

		// Mark the ballot as finalized (which will also remove it from the list of open token whitelisting proposals)
		proposals.markBallotAsFinalized(ballotID);
		}


	// Finalize the vote on a specific ballot
	function finalizeBallot( uint256 ballotID ) public nonReentrant
		{
		// Checks that ballot is live, and minimumEndTime and quorum have both been reached
		require( proposals.canFinalizeBallot(ballotID), "The ballot is not yet able to be finalized" );

		Ballot memory ballot = proposals.ballotForID(ballotID);

		if ( ballot.ballotType == BallotType.PARAMETER )
			_finalizeParameterBallot(ballotID);
		else if ( ballot.ballotType == BallotType.WHITELIST_TOKEN )
			_finalizeTokenWhitelisting(ballotID);
		else
			_finalizeApprovalBallot(ballotID);
		}


	// Withdraw the WETH arbitrage profits deposited in the Pools contract and send them to the caller (the Upkeep contract)
	function withdrawArbitrageProfits( IERC20 weth ) public
		{
		require( msg.sender == address(exchangeConfig.upkeep()), "DAO.withdrawArbitrageProfits is only callable from the Upkeep contract" );

		uint256 depositedWETH =  pools.depositedBalance(address(this), weth );
		if ( depositedWETH == 0 )
			return;

		pools.withdraw( weth, depositedWETH );

		uint256 wethBalance = weth.balanceOf( address(this) );
		weth.safeTransfer( msg.sender, wethBalance );
		}


	// Form Protocol Owned Liquidity with any SALT and USDS in the contract
	// Any SALT or USDS that is not used will be stay in the DAO contract.
	function formPOL( ILiquidity liquidity, ISalt salt, IUSDS usds ) public
		{
		require( msg.sender == address(exchangeConfig.upkeep()), "DAO.formPOL is only callable from the Upkeep contract" );

		uint256 balanceA = salt.balanceOf( address(this) );
		uint256 balanceB = usds.balanceOf( address(this) );

		require( balanceA > 0, "formPOL: balanceA cannot be zero" );
		require( balanceB > 0, "formPOL: balanceB cannot be zero" );

		salt.approve(address(liquidity), balanceA);
		usds.approve(address(liquidity), balanceB);

		liquidity.addLiquidityAndIncreaseShare( salt, usds, balanceA, balanceB, 0, block.timestamp, true );
		}


	// Send SALT which was withdrawn from counterswap and not used for POL to SaltRewards
	function sendSaltToSaltRewards( ISalt salt, ISaltRewards saltRewards, uint256 amountToSend) public
		{
		require( msg.sender == address(exchangeConfig.upkeep()), "DAO.sendSaltToSaltRewards is only callable from the Upkeep contract" );

		salt.approve( address(saltRewards), amountToSend );
		saltRewards.addSALTRewards(amountToSend);
		}


	function processRewardsFromPOL(ILiquidity liquidity, ISalt salt, IUSDS usds) public
		{
		require( msg.sender == address(exchangeConfig.upkeep()), "DAO.processRewardsFromPOL is only callable from the Upkeep contract" );

		// The DAO owns SALT/USDS which it forms on an ongoing basis
		bytes32[] memory protocolOwnedLiquidityPoolIDs = new bytes32[](1);
		(protocolOwnedLiquidityPoolIDs[0],) = PoolUtils._poolID(salt, usds);

		uint256 claimedAmount = liquidity.claimAllRewards(protocolOwnedLiquidityPoolIDs);

		// Send 10% of the rewards to the team
		uint256 amountToSendToTeam = ( claimedAmount * 10 ) / 100;
		salt.safeTransfer( exchangeConfig.teamWallet(), amountToSendToTeam );

		uint256 remainingAmount = claimedAmount - amountToSendToTeam;

		// Burn a default 75% of the remaining SALT that was just claimed (the rest of the SALT stays in the DAO contract)
		uint256 saltToBurn = ( remainingAmount * daoConfig.percentPolRewardsBurned() ) / 100;

		salt.safeTransfer( address(salt), saltToBurn );
		salt.burnTokensInContract();
		}


	// Initially excluded countries as voted on by the airdrop recipients on the bootstrap ballot
	// Any excluded country can be re-included by the DAO after launch as needed.
	function initialGeoExclusion(uint256[] memory geoExclusionYes, uint256[] memory geoExclusionNo) public
		{
		require( msg.sender == address(exchangeConfig.initialDistribution().bootstrapBallot()), "DAO.initialGeoExclusion can only be called from the BootstrapBallot" );

		// Exclude the United States?
		if ( geoExclusionYes[0] > geoExclusionNo[0] )
			excludedCountries["USA"] = true;

		// Exclude Canada?
		if ( geoExclusionYes[1] > geoExclusionNo[1] )
			excludedCountries["CAN"] = true;

		// Exclude the United Kingdom?
		if ( geoExclusionYes[2] > geoExclusionNo[2] )
			excludedCountries["GBR"] = true;

		// Exclude China, Cuba, India, Pakistan, Russia?
		if ( geoExclusionYes[3] > geoExclusionNo[3] )
			{
			excludedCountries["CHN"] = true;
			excludedCountries["CUB"] = true;
			excludedCountries["IND"] = true;
			excludedCountries["PAK"] = true;
			excludedCountries["RUS"] = true;
			}

		// Exclude Afghanistan, Iran, North Korea, Syria, Venezuela?
		if ( geoExclusionYes[4] > geoExclusionNo[4] )
			{
			excludedCountries["AFG"] = true;
			excludedCountries["IRN"] = true;
			excludedCountries["PRK"] = true;
			excludedCountries["SYR"] = true;
			excludedCountries["VEN"] = true;
			}
		}


	// === VIEWS ===

	// Finalization only possible for whitelisting tokens if the SALT balance in the DAO contract satisfies the bootstrapping rewards (as specified in daoConfig).
	function sufficientBootstrappingRewardsExistForWhitelisting() public view returns (bool)
		{
		// Make sure that the DAO contracts holds the required amount of SALT for bootstrappingRewards.
		// Twice the specified rewards are needed (for both the token/WBTC and token/WETH pools which will be whitelisted)
		uint256 saltBalance = exchangeConfig.salt().balanceOf( address(this) );
		if ( saltBalance < daoConfig.bootstrappingRewards() * 2 )
			return false;

		return true;
		}


	function countryIsExcluded( string memory country ) public view returns (bool)
		{
		return excludedCountries[country];
		}
	}