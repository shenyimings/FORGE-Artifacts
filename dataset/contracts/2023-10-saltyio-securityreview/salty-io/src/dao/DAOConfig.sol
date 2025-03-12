// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IDAOConfig.sol";


// Contract owned by the DAO with parameters modifiable only by the DAO
contract DAOConfig is IDAOConfig, Ownable
    {
	// The amount of SALT provided as a bootstrapping reward when a new token is whitelisted.
	// Note that new tokens will only be able to be whitelisted (even if the vote is favorable) once the DAO SALT balance is at least this amount.
	// The DAO receives 25 million SALT (linearly over 10 years - about 48k per week) as well as default ~23% of the Protocol Owned Liquidity SALT rewards.
	// Range: 50k ether to 500k ether with an adjustment of 50k ether
	uint256 public bootstrappingRewards = 100000 ether;

	// For rewards distributed to the DAO, the percentage of SALT that is burned with the remaining staying in the DAO for later use
	// Range: 60% to 90% with an adjustment of 5%
    uint256 public percentPolRewardsBurned = 75;

	// The minimum amount of xSALT required for ballot quorum (to take action on the ballot).
	// baseBallotQuorum is decided as a percent of the total amount of SALT staked.
	// NOTE: there is a hard minimum of 1% of SALT.totalSupply that takes effect if the amount of staked SALT is low (at launch for instance).
	// Parameter adjustment quorum: = 1 * baseBallotQuorum
	// Token whitelisting quorum: = 2 * baseBallotQuorum
	// Sending SALT from the DAO quorum: = 3 * baseBallotQuorum
	// Country whitelisting quorum: = 3 * baseBallotQuorum
	// Contract updating quorum: = 3 * baseBallotQuorum
	// Website updating quorum: = 3 * baseBallotQuorum
	// Range: 5% to 20% with an adjustment of 1%
	uint256 public baseBallotQuorumPercentTimes1000 = 10 * 1000; // Default 10% of the total amount of SALT staked

	// How many days minimum a ballot has to exist before it can be taken action on.
	// Action will only be taken if it has the required votes and quorum to do so.
	// Range: 3 to 14 days with an adjustment of 1 day
	uint256 public ballotDuration = 10 days;

	// The base USDS cost to propose a ballot to the DAO.
	// This cost is paid at the time the proposal is made - whether or not it is eventually approved by the voters.
	// Range: 250 ether to 5000 ether with an adjustment of 250 ether.
	// Parameter adjustment cost: = 1 * baseProposalCost
	// Token whitelisting cost: = 2 * baseProposalCost
	// Sending SALT from the DAO cost: = 3 * baseProposalCost
	// Country whitelisting cost: = 5 * baseProposalCost
	// Contract updating cost: = 10 * baseProposalCost
	// Website updating cost: = 10 * baseProposalCost
	uint256 public baseProposalCost = 500 ether;

	// The maximum number of tokens that can be pending for whitelisting at any time.
	// Range: 3 to 12 with an adjustment of 1
	uint256 public maxPendingTokensForWhitelisting = 5;

	// The share of the WETH arbitrage profits that are sent to the DAO to form Protocol Owned Liquidity
	// Range: 15% to 45% with an adjustment of 5%
	uint256 public arbitrageProfitsPercentPOL = 20;

	// The share of the WETH arbitrage profits sent to the DAO that are sent to the caller of DAO.performUpkeep()
	// Range: 1% to 10% with an adjustment of 1%
	uint256 public upkeepRewardPercent = 5;


	function changeBootstrappingRewards(bool increase) public onlyOwner
		{
        if (increase)
        	{
            if (bootstrappingRewards < 500000 * 1 ether)
                bootstrappingRewards += 50000 * 1 ether;
            }
       	 else
       	 	{
            if (bootstrappingRewards > 50000 * 1 ether)
                bootstrappingRewards -= 50000 * 1 ether;
	        }
    	}


	function changePercentPolRewardsBurned(bool increase) public onlyOwner
		{
		if (increase)
			{
			if (percentPolRewardsBurned < 90)
				percentPolRewardsBurned += 5;
			}
		else
			{
			if (percentPolRewardsBurned > 60)
				percentPolRewardsBurned -= 5;
			}
		}


	function changeBaseBallotQuorumPercent(bool increase) public onlyOwner
		{
		if (increase)
			{
			if (baseBallotQuorumPercentTimes1000 < 20 * 1000)
				baseBallotQuorumPercentTimes1000 += 1000;
			}
		else
			{
			if (baseBallotQuorumPercentTimes1000 > 5 * 1000 )
				baseBallotQuorumPercentTimes1000 -= 1000;
			}
		}

	function changeBallotDuration(bool increase) public onlyOwner
    	{
        if (increase)
        	{
            if (ballotDuration < 14 days)
                ballotDuration += 1 days;
        	}
        else
        	{
            if (ballotDuration > 3 days)
                ballotDuration -= 1 days;
        	}
    	}


	function changeBaseProposalCost(bool increase) public onlyOwner
    	{
        if (increase)
        	{
            if (baseProposalCost < 5000 ether)
                baseProposalCost += 250 ether;
        	}
        else
        	{
            if (baseProposalCost > 250 ether)
                baseProposalCost -= 250 ether;
    	    }
	    }


	function changeMaxPendingTokensForWhitelisting(bool increase) public onlyOwner
		{
		if (increase)
			{
			if (maxPendingTokensForWhitelisting < 12)
				maxPendingTokensForWhitelisting += 1;
			}
		else
			{
			if (maxPendingTokensForWhitelisting > 3)
				maxPendingTokensForWhitelisting -= 1;
			}
		}


	function changeArbitrageProfitsPercentPOL(bool increase) public onlyOwner
        {
        if (increase)
            {
            if (arbitrageProfitsPercentPOL < 45)
                arbitrageProfitsPercentPOL += 5;
            }
        else
            {
            if (arbitrageProfitsPercentPOL > 15)
                arbitrageProfitsPercentPOL -= 5;
            }
		}


	function changeUpkeepRewardPercent(bool increase) public onlyOwner
        {
        if (increase)
            {
            if (upkeepRewardPercent < 10)
                upkeepRewardPercent += 1;
            }
        else
            {
            if (upkeepRewardPercent > 1)
                upkeepRewardPercent -= 1;
            }
        }
    }