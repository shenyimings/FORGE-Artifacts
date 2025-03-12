// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../core/Pancake.sol";
import "../core/Tokenomics.sol";
import "../core/RFI.sol";
import "../core/Supply.sol";
import "../features/TxPolice.sol";
import "../libraries/Percent.sol";

abstract contract Distribution is Ownable, Tokenomics, Pancake, RFI, Supply, TxPolice {
	using SafeMath for uint256;
	using Percent for uint256;
	// Will keep tabs on how much BNB from the balance belongs for distribution.
	uint256 public bnbAccumulatedForDistribution;
	// Distribution feature toggle
	bool public isDistributionEnabled;
	// This will hold maximum claimable BNB amount for a distribution cycle.
	uint256 public claimableDistribution;
	// Will show total BNB claimed from the beginning of distribution launch.
	uint256 public totalClaimed;
	// Will show total BNB claimed for teh current cycle.
	uint256 public totalClaimedDuringCycle;
	// Will keep the record about the last claim by holder.
	mapping(address => uint256) internal claimedTimestamp;
	// Record of when was the last cycle set
	uint256 public lastCycleResetTimestamp;
	// Hour multiplier
	uint256 private hour = 60 * 60;
	// Amount of hours for a claim cycle. Cycle will be reset after this passes.
	uint256 public claimCycleHours;

	/** 
	* @notice Checks if all required prerequisites are met for us to trigger 
	* selling of the tokens for later distribution.
	*/
	function canSellForDistribution(
		uint256 contractTokenBalance
	) 
		internal 
		view
		returns(bool) 
	{
		return contractTokenBalance >= accumulatedForDistribution 
			&& accumulatedForDistribution >= minToDistribution;
	}

	/**
	* @notice Sells tokens accumulated for distibution. Receives BNB.
	* Updates the BNB accumulator so we know how much to use for distribution later.
	*	@param tokenAmount amount of tokens to take from balance and sell.
	* NOTE: needs to be tested on testnet!!!
	*/
	function sellForDistribution(
		uint256 tokenAmount
	) internal lockTheProcess {
		// Must approve before swapping.
		rfiApprove(address(this), address(uniswapV2Router), tokenAmount);
		uint256 bnbReceived = swapTokensForBnb(tokenAmount);
		// Increment BNB accumulator
		bnbAccumulatedForDistribution = bnbAccumulatedForDistribution.add(bnbReceived);
		// Reset the accumulator.
		accumulatedForDistribution = 0;
		emit SoldTokensForDistribution(tokenAmount, bnbReceived);
	}

	/**
	* @notice External function allows to enable the reward distribution feature.
	* Some BNB must be already accumulated for this to work.
	* NOTE: Can be used to reset the cycle from the outside too.
	* @param cycleHours set or reset the hours for the distribution cycle
	* @return amount of BNB set as claimable for this cycle
	*/
	function enableRewardDistribution(uint256 cycleHours) 
		external 
		onlyOwner 
		returns(uint256) 
	{
		require(cycleHours > 0, "Cycle hours can't be 0.");
		require(bnbAccumulatedForDistribution > 0, "Don't have BNB for distribution.");
		isDistributionEnabled = true;
		resetClaimDistributionCycle(cycleHours);
		return claimableDistribution;
	}

	/**
	* @notice External function allowing to stop reward distribution.
	* NOTE: must call enableRewardDistribution() to start it again.
	*/
	function disableRewardDistribution() external onlyOwner returns(bool) {
		isDistributionEnabled = false;
		return true;
	}

	/**
	* @notice Tells if reward claim cycle has ended since the last reset.
	*/
	function hasCyclePassed() public view returns(bool) {
		uint256 timeSinceReset = block.timestamp.sub(lastCycleResetTimestamp);
		return timeSinceReset > claimCycleHours.mul(hour);
	}

	/**
	* @notice Tells if the address has already claimed during the current cycle.
	*/
	function hasAlreadyClaimed(address holderAddr) public view returns(bool) {
		uint256 lastClaim = claimedTimestamp[holderAddr];
		uint256 timeSinceLastClaim = block.timestamp.sub(lastClaim);
		return timeSinceLastClaim < claimCycleHours.mul(hour);
	}

	/**
	* @notice Calculates a share of BNB belonging to a holder based on his holdings.
	*/
	function calcClaimableShare(address holderAddr) public view returns(uint256) {
		uint256 circulatingSupply = totalCirculatingSupply();
		uint256 LPTokens = balanceOf(uniswapV2Pair);
		uint256 totalHoldingAmount = circulatingSupply.sub(LPTokens);
		uint256 bnbShare = totalHoldingAmount.percent(balanceOf(holderAddr), 18);
		uint256 bnbToSend = bnbShare.percentOf(claimableDistribution, 1 * 10 ** 18);






		return bnbToSend;
	}

	/**
	* @notice Resets the reward claim cycle with a new hours value. 
	* Assigns new 'claimableDistribution' and resets lastCycleResetTimestamp.
	*/
	function resetClaimDistributionCycle(uint256 cycleHours) 
		internal
	{
		require(cycleHours > 0, "Cycle hours can't be 0.");

		claimCycleHours = cycleHours;
		// Update the total for the historic record
		totalClaimed = totalClaimed.add(totalClaimedDuringCycle);
		// First sync main accumulator


		bnbAccumulatedForDistribution = bnbAccumulatedForDistribution.sub(
			totalClaimedDuringCycle
		);
		// Don't forget to reset total for cycle!
		totalClaimedDuringCycle = 0;
		// Set claimable with the synced main accumulator
		claimableDistribution = bnbAccumulatedForDistribution;

		// Rest time stamp
		lastCycleResetTimestamp = block.timestamp;
	}

	/**
	* Allows any holder to call this function and claim the a share of BNB 
	* belonging to him basec on the holding amount, current claimable amount.
	* Claiming can be done only once per cycle.
	*/
	function claimReward() 
		external
		onlyHolder
		returns(uint256)
	{
		address sender = _msgSender();
		require(isDistributionEnabled, "Distribution is disabled.");
		require(!hasAlreadyClaimed(sender), "Already claimed in the current cycle.");
		if (hasCyclePassed()) {
			// Reset with same cycle hours.
			resetClaimDistributionCycle(claimCycleHours);
		}
		uint256 bnbShare = calcClaimableShare(sender);
		payable(sender).transfer(bnbShare);
		claimedTimestamp[sender] = block.timestamp;
		totalClaimedDuringCycle = totalClaimedDuringCycle.add(bnbShare);
		return bnbShare;
	}

/* --------------------------------- Events --------------------------------- */

	event SoldTokensForDistribution(
		uint256 tokensSold,
		uint256 bnbReceived
	);
}