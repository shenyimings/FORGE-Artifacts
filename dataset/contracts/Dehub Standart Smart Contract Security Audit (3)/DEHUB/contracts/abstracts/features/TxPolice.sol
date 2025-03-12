// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../core/Pancake.sol";
import "../core/Tokenomics.sol";
import "../core/RFI.sol";
import "../core/Supply.sol";

abstract contract TxPolice is Tokenomics, Pancake, RFI, Supply {
	using SafeMath for uint256;
	// Wallet hard cap 0.01% of total supply
	uint256 public maxWalletSize = _tTotal.mul(1).div(100);
	// 0.01% per transaction
	uint256 public maxTxAmount = _tTotal.mul(1).div(100);
	// Convenience enum to differentiate transaction limit types.
	enum TransactionLimitType { TRANSACTION, WALLET, SELL }
	// Convenience enum to differentiate transaction types.
	enum TransactionType { REGULAR, SELL, BUY }

	// Global toggle to avoid trigger loops
	bool internal inTriggerProcess;
	modifier lockTheProcess {
		inTriggerProcess = true;
		_;
		inTriggerProcess = false;
	}

	// Sometimes you just have addresses which should be exempt from any 
	// limitations and fees.
	mapping(address => bool) public specialAddresses;

	// Toggle multiple exemptions from transaction limits.
	struct LimitExemptions {
		bool all;
		bool transaction;
		bool wallet;
		bool sell;
		bool fees;
	}

	// Keeps a record of addresses with limitation exemptions
	mapping(address => LimitExemptions) internal limitExemptions;

/* --------------------------- Exemption Utilities -------------------------- */

	/**
	* @notice External function allowing owner to toggle various limit exemptions
	* for any address.
	*/
	function toggleLimitExemptions(
		address addr, 
		bool allToggle, 
		bool txToggle, 
		bool walletToggle, 
		bool sellToggle,
		bool feesToggle
	) 
		public 
		onlyOwner
	{
		LimitExemptions memory ex = limitExemptions[addr];
		ex.all = allToggle;
		ex.transaction = txToggle;
		ex.wallet = walletToggle;
		ex.sell = sellToggle;
		ex.fees = feesToggle;
		limitExemptions[addr] = ex;
	}

	/**
	* @notice External function allowing owner toggle any address as special address.
	*/
	function toggleSpecialWallets(address specialAddr, bool toggle) 
		external 
		onlyOwner 
	{
		specialAddresses[specialAddr] = toggle;
	}

/* ------------------------------- Sell Limit ------------------------------- */
	// Toggle for sell limit feature
	bool public isSellLimitEnabled = true;
	// Sell limit cycle period
	uint256 public sellCycleHours = 24;
	// Hour multiplier
	uint256 private hour = 60 * 60;
	// Changing this you can increase/decrease decimals of your maxSellAllowancePerCycle 
	uint256 public maxSellAllowanceMultiplier = 1000;
	// (address => amount)
	mapping(address => uint256) private cycleSells;
	// (address => lastTimestamp)
	mapping(address => uint256) private lastSellTimestamp;

	/**
	* @notice Tracks and limits sell transactions per user per cycle set.
	* Unless user is a special address or has exemptions.
	*/
	function enforceCyclicSellLimit(address from, address to, uint256 amount) 
		internal 
	{
		// Identify if selling... otherwise quit.
		bool isSell = getTransactionType(from, to) == TransactionType.SELL;

		// Guards
		// Get exemptions if any for tx sender and receiver.
		if (
			limitExemptions[from].all
			|| limitExemptions[from].sell
			|| specialAddresses[from] 
			|| !isSellLimitEnabled
		) { 





			return; 
		}

		if (!isSell) { return; }

		// First check if sell amount doesn't exceed total max allowance.
		uint256 maxAllowance = maxSellAllowancePerCycle();

		require(amount <= maxAllowance, "Can't sell more than cycle allowance!");

		// Then check if sell cycle has passed. If so, just update the maps and quit.
		if (hasSellCycleEnded(from)) {
			lastSellTimestamp[from] = block.timestamp;
			cycleSells[from] = amount;
			return;
		}

		// If cycle has not yet passed... check if combined amount doesn't excceed the max allowance.
		uint256 combinedAmount = amount.add(cycleSells[from]);

		require(combinedAmount <= maxAllowance, "Combined cycle sell amount exceeds cycle allowance!");

		// If all good just increment sells map. (don't update timestamp map, cause then 
		// sell cycle will never end for this poor holder...)
		cycleSells[from] = combinedAmount;
		return;
	}

	/**
	 * @notice Calculates current maximum sell allowance per day based on the 
	 * total circulating supply.
	 */
	function maxSellAllowancePerCycle() public view returns(uint256) {
		// 0.1% of total circulating supply.
		return totalCirculatingSupply().mul(1).div(maxSellAllowanceMultiplier);
	}

	/**
	* @notice Allows to adjust your maxSellAllowancePerCycle.
	* 1000 = 0.1% 
	*/
	function setMaxSellAllowanceMultiplier(uint256 mult) external onlyOwner {
		require(mult > 0, "Multiplier can't be 0.");
		maxSellAllowanceMultiplier = mult;
	}

	function hasSellCycleEnded(address holderAddr) 
		internal 
		view  
		returns(bool) 
	{
		uint256 lastSell = lastSellTimestamp[holderAddr];
		uint256 timeSinceLastSell = block.timestamp.sub(lastSell);
		bool cycleEnded = timeSinceLastSell >= sellCycleHours.mul(hour);



		return cycleEnded;
	}

	/**
	* @notice External functions which allows to set selling limit period.
	*/
	function setSellCycleHours(uint256 hoursCycle) external onlyOwner {
		require(hoursCycle >= 0, "Hours can't be 0.");
		sellCycleHours = hoursCycle;
	}

	/**
	* @notice External functions which allows to disable selling limits.
	*/
	function disableSellLimit() external onlyOwner {
		require(isSellLimitEnabled, "Selling limit already enabled.");
		isSellLimitEnabled = false;
	}

	/**
	* @notice External functions which allows to enable selling limits.
	*/
	function enableSellLimit() external onlyOwner {
		require(!isSellLimitEnabled, "Selling limit already disabled.");
		isSellLimitEnabled = true;
	}

	/**
	* @notice External function which can be called by a holder to see how much 
	* sell allowance is left for the current cycle period.
	*/
	function sellAllowanceLeft() external view returns(uint256) {
		address sender = _msgSender();
		bool isSpecial = specialAddresses[sender];
		bool isExemptFromAll = limitExemptions[sender].all;
		bool isExemptFromSell = limitExemptions[sender].sell;
		bool isExemptFromWallet = limitExemptions[sender].wallet;
		
		// First guard exemptions
		if (
			isSpecial || isExemptFromAll 
			|| (isExemptFromSell && isExemptFromWallet)) 
		{
			return balanceOf(sender);
		} else if (isExemptFromSell && !isExemptFromWallet) {
			return maxWalletSize;
		}

		// Next quard toggle and check cycle
		uint256 maxAllowance = maxWalletSize;
		if (isSellLimitEnabled) {
			maxAllowance = maxSellAllowancePerCycle();
			if (!hasSellCycleEnded(sender)) {
				maxAllowance = maxAllowance.sub(cycleSells[sender]);
			}
		} else if (isExemptFromWallet) {
			maxAllowance = balanceOf(sender);
		}
		return maxAllowance;
	}

/* --------------------------------- Guards --------------------------------- */

	/**
	* @notice Checks passed multiple limitTypes and if required enforces maximum
	* limits.
	* NOTE: extend this function with more limit types if needed.
	*/
	function guardMaxLimits(
		address from, 
		address to, 
		uint256 amount,
		TransactionLimitType[2] memory limitTypes
	) internal view {
		// Get exemptions if any for tx sender and receiver.
		LimitExemptions memory senderExemptions = limitExemptions[from];
		LimitExemptions memory receiverExemptions = limitExemptions[to];

		// First check if any special cases
		if (
			senderExemptions.all && receiverExemptions.all 
			|| specialAddresses[from] 
			|| specialAddresses[to] 
			|| liquidityPools[to]
		) { return; }

		// If no... then go through each limit type and apply if no exemptions.
		for (uint256 i = 0; i < limitTypes.length; i += 1) {
			if (
				limitTypes[i] == TransactionLimitType.TRANSACTION 
				&& !senderExemptions.transaction
			) {
				require(
					amount <= maxTxAmount,
					"Transfer amount exceeds the maxTxAmount."
				);
			}
			if (
				limitTypes[i] == TransactionLimitType.WALLET 
				&& !receiverExemptions.wallet
			) {
				uint256 toBalance = balanceOf(to);
				require(
					toBalance.add(amount) <= maxWalletSize,
					"Exceeds maximum wallet size allowed."
				);
			}
		}
	}

/* ---------------------------------- Fees ---------------------------------- */

function canTakeFee(address from, address to) 
	internal view returns(bool) 
{	
	bool take = true;
	if (
		limitExemptions[from].all 
		|| limitExemptions[to].all
		|| limitExemptions[from].fees 
		|| limitExemptions[to].fees 
		|| specialAddresses[from] 
		|| specialAddresses[to]
	) { take = false; }

	return take;
}

/**
	* @notice Updates old and new wallet fee exemptions.
	*/
	function swapExcludedFromFee(address newWallet, address oldWallet) internal {
		if (oldWallet != address(0)) {
			toggleLimitExemptions(oldWallet, false, false, false, false, false);
		}
		toggleLimitExemptions(newWallet, false, false, false, true, true);
	}

/* --------------------------------- Helpers -------------------------------- */

	/**
	* @notice Helper function to determine what kind of transaction it is.
	* @param from transaction sender
	* @param to transaction receiver
	*/
	function getTransactionType(address from, address to) 
		internal view returns(TransactionType)
	{
		if (liquidityPools[from] && !liquidityPools[to]) {
			// LP -> addr
			return TransactionType.BUY;
		} else if (!liquidityPools[from] && liquidityPools[to]) {
			// addr -> LP
			return TransactionType.SELL;
		}
		return TransactionType.REGULAR;
	}
}