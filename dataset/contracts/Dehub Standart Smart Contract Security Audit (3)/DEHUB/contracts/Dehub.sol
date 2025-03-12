// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;



import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./abstracts/core/Tokenomics.sol";
import "./abstracts/core/RFI.sol";
import "./abstracts/features/Liquify.sol";
import "./abstracts/features/Expensify.sol";
import "./abstracts/features/Buyback.sol";
import "./abstracts/features/Collateralize.sol";
import "./abstracts/features/Distribution.sol";
import "./abstracts/features/TxPolice.sol";
import "./abstracts/core/Pancake.sol";
import "./abstracts/helpers/Helpers.sol";



contract DEHUB is 
	IERC20Metadata, 
	Context, 
	Ownable, 
	ReentrancyGuard, 
	Tokenomics, 
	RFI,
	TxPolice,
	Liquify, 
	Expensify, 
	Buyback, 
	Collateralize, 
	Distribution
{
	using SafeMath for uint256;

	constructor() {
		// Set limit exemptions
		LimitExemptions memory exemptions;
		exemptions.all = true;
		limitExemptions[owner()] = exemptions;
		limitExemptions[address(this)] = exemptions;
		// Set special addresses
		specialAddresses[owner()] = true;
		specialAddresses[address(this)] = true;
		specialAddresses[deadAddr] = true;
	}

/* ------------------------------- IERC20 Meta ------------------------------ */

	function name() external pure override returns(string memory) { return NAME;}
	function symbol() external pure override returns(string memory) { return SYMBOL;}
	function decimals() external pure override returns(uint8) { return DECIMALS; }	

/* -------------------------------- Overrides ------------------------------- */

	function beforeTokenTransfer(address from, address to, uint256 amount) 
		internal 
		override 
	{


		// Make sure max transaction and wallet size limits are not exceeded.
		TransactionLimitType[2] memory limits = [
			TransactionLimitType.TRANSACTION, 
			TransactionLimitType.WALLET
		];
		guardMaxLimits(from, to, amount, limits);
		enforceCyclicSellLimit(from, to, amount);
		// Try to execute all our accumulator features.
		triggerFeatures(from);
	}

	function takeFee(address from, address to) 
		internal 
		view 
		override 
		returns(bool) 
	{
		return canTakeFee(from, to);
	}

/* -------------------------- Accumulator Triggers -------------------------- */

	// Will keep track of how often each trigger has been called already.
	uint256[5] internal triggerLog = [0, 0, 0, 0, 0];
	// Will keep track of trigger indexes, which can be triggered during current tx.
	uint8[] internal canTrigger;
	
	/**
	* @notice Returns the smallest trigger log count value.
	*/
	function getSmallestTriggerLogCount() internal view returns(uint256) {
		uint256 smallest = triggerLog[0];
		for (uint8 i = 1; i < triggerLog.length; i++) {
				if (triggerLog[i] < smallest) {
						smallest = triggerLog[i];
				}
		}
		return smallest;
	}

	/**
	* @notice Trigger throttling mechanism. Allows to prioritize and execute only 
	* single trigger per transaction to avoid high gas fees.
	* Idea: the most frequent trigger is the smallest priority, the least frequent
	* is the most priority. If more than one trigger can be called during the tx 
	* we trigger the most priority one and then on the next tx, other one will be 
	* called and so on.
	*/
	function resolveTrigger() internal {
		uint256 smallest = getSmallestTriggerLogCount();

		for (uint8 i = 0; i < canTrigger.length; i++) {
			uint8 index = canTrigger[i];
			if (triggerLog[index] == smallest) {
				if (index == 0) {
					_triggerLiquify();
					delete canTrigger;
					break;
				} else if (index == 1) {
					_triggerExpensify();
					delete canTrigger;
					break;
				} else if (index == 2) {
					_triggerSellForBuyback();
					delete canTrigger;
					break;
				} else if (index == 3) {
					_triggerSellForCollateral();
					delete canTrigger;
					break;
				} else if (index == 4) {
					_triggerSellForDistribution();
					delete canTrigger;
					break;
				}
			}
		}
	}

	/**
	* @notice Populates canTrigger array with the indexes of the the triggers, 
	* which can be triggered during this tx.
	*/
	function resolveWhatCanBeTriggered() internal {
		uint256 contractTokenBalance = balanceOf(address(this));
		if (canLiquify(contractTokenBalance)) {
				canTrigger.push(0);
			}
			if (canExpensify(contractTokenBalance)) {
				canTrigger.push(1);
			}
			if (canSellForBuyback(contractTokenBalance)) {
				canTrigger.push(2);
			}
			if (canSellForCollateral(contractTokenBalance)) {
				canTrigger.push(3);
			}
			if (canSellForDistribution(contractTokenBalance)) {
				canTrigger.push(4);
			}
	}

	/**
	* @notice Convenience wrapper function which tries to trigger our custom 
	* features.
	*/
	function triggerFeatures(address from) private {






		
		// First determine which triggers can be triggered.
		if (!liquidityPools[from]) {
			resolveWhatCanBeTriggered();
		}

		// Avoid falling into a tx loop.
		if (!inTriggerProcess) {
			// Decide which trigger will be triggered and triger it.
			resolveTrigger();
		}
	}

/* ---------------------------- Internal Triggers --------------------------- */

	/**
	* @notice Triggers liquify and updates triggerLog
	*/
	function _triggerLiquify() internal {

		swapAndLiquify(accumulatedForLiquidity);
		triggerLog[0] = triggerLog[0].add(1);
	}

	/**
	* @notice Triggers expensify and updates triggerLog
	*/
	function _triggerExpensify() internal {

		expensify(accumulatedForExpenses);
		triggerLog[1] = triggerLog[1].add(1);
	}

	/**
	* @notice Triggers sell for buyback and updates triggerLog
	*/
	function _triggerSellForBuyback() internal {

		sellForBuyback(accumulatedForBuyback);
		triggerLog[2] = triggerLog[2].add(1);
	}

	/**
	* @notice Triggers sell for collateral and updates triggerLog
	*/
	function _triggerSellForCollateral() internal {

		sellForCollateral(accumulatedForCollateral);
		triggerLog[3] = triggerLog[3].add(1);
	}

	/**
	* @notice Triggers sell for distribution and updates triggerLog
	*/
	function _triggerSellForDistribution() internal {

		sellForDistribution(accumulatedForDistribution);
		triggerLog[4] = triggerLog[4].add(1);
	}

/* ---------------------------- External Triggers --------------------------- */

	/**
	* @notice Allows to trigger liquify manually.
	*/
	function triggerLiquify() external onlyOwner {
		uint256 contractTokenBalance = balanceOf(address(this));
		require(canLiquify(contractTokenBalance), 'Not enough tokens accumulated.');
		_triggerLiquify();
	}

	/**
	* @notice Allows to trigger expensify manually.
	*/
	function triggerExpensify() external onlyOwner {
		uint256 contractTokenBalance = balanceOf(address(this));
		require(canExpensify(contractTokenBalance), 'Not enough tokens accumulated.');
		_triggerExpensify();
	}

	/**
	* @notice Allows to trigger sell for buyback manually.
	*/
	function triggerSellForBuyback() external onlyOwner {
		uint256 contractTokenBalance = balanceOf(address(this));
		require(canSellForBuyback(contractTokenBalance), 'Not enough tokens accumulated.');
		_triggerSellForBuyback();
	}

	/**
	* @notice Allows to trigger sell for collateral manually.
	*/
	function triggerSellForCollateral() external onlyOwner {
		uint256 contractTokenBalance = balanceOf(address(this));
		require(canSellForCollateral(contractTokenBalance), 'Not enough tokens accumulated.');
		_triggerSellForCollateral();
	}

	/**
	* @notice Allows to sell for distribution manually.
	*/
	function triggerSellForDistribution() external onlyOwner {
		uint256 contractTokenBalance = balanceOf(address(this));
		require(canSellForDistribution(contractTokenBalance), 'Not enough tokens accumulated.');
		_triggerSellForDistribution();
	}

}