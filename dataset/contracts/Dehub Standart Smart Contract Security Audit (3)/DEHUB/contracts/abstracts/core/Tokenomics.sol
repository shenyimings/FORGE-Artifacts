// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Tokenomics is IERC20, Ownable {
	using SafeMath for uint256;

/* ---------------------------------- Token --------------------------------- */

	string internal constant NAME = "DeHub";
	string internal constant SYMBOL = "DeHub";

	uint8 internal constant DECIMALS = 5;
	uint256 internal constant ZEROES = 10 ** DECIMALS;

	uint256 private constant MAX = ~uint256(0);
	uint256 internal constant _tTotal = 8000000000 * ZEROES;
	uint256 internal _rTotal = (MAX - (MAX % _tTotal));

	address public deadAddr = 0x000000000000000000000000000000000000dEaD;

/* ---------------------------------- Fees ---------------------------------- */

	uint256 internal _tFeeTotal;

	// Will be redistributed amongst holders
	uint256 public _taxFee = 1;
	// Used to cache fee when removing fee temporarily.
	uint256 internal _previousTaxFee = _taxFee;
	// Will be used for liquidity
	uint256 public _liquidityFee = 2;
	// Used to cache fee when removing fee temporarily.
	uint256 internal _previousLiquidityFee = _liquidityFee;
	// Will keep tabs on the amount which should be taken from wallet for liquidity.
	uint256 public accumulatedForLiquidity = 0;
	// Will be used for expenses (dev, licensing, marketing)
	uint256 public _expensesFee = 1;
	// Used to cache fee when removing fee temporarily.
	uint256 internal _previousExpensesFee = _expensesFee;
	// Will keep tabs on the amount which should be taken from wallet for expenses.
	uint256 public accumulatedForExpenses = 0;
	// Will be used for buyback
	uint256 public _buybackFee = 4;
	// Used to cache fee when removing fee temporarily.
	uint256 internal _previousBuybackFee = _buybackFee;
	// Will keep tabs on the amount which should be taken from wallet for buyback.
	uint256 public accumulatedForBuyback = 0;
	// Will be sold for BNB and distributed to holders as rewards.
	uint256 public _distributionFee = 2;
	// Used to cache fee when removing fee temporarily.
	uint256 internal _previousDistributionFee = _distributionFee;
	// Will keep tabs on the amount which should be taken from wallet for distribution.
	uint256 public accumulatedForDistribution = 0;
	// Will be sold for BNB and used as a collateral funds.
	uint256 public _collateralFee = 2;
	// Used to cache fee when removing fee temporarily.
	uint256 internal _previousCollateralFee = _collateralFee;
	// Will keep tabs on the amount which should be taken from wallet for collateral.
	uint256 public accumulatedForCollateral = 0;

	/**
	 * @notice Temporarily stops all fees. Caches the fees into secondary variables,
	 * so it can be reinstated later.
	 */
	function removeAllFee() internal {
		if (_taxFee == 0 &&
			_liquidityFee == 0 &&
			_expensesFee == 0 &&
			_buybackFee == 0 &&
			_distributionFee == 0 &&
			_collateralFee == 0
		) return;

		_previousTaxFee = _taxFee;
		_previousLiquidityFee = _liquidityFee;
		_previousExpensesFee = _expensesFee;
		_previousBuybackFee = _buybackFee;
		_previousDistributionFee = _distributionFee;
		_previousCollateralFee = _collateralFee;

		_taxFee = 0;
		_liquidityFee = 0;
		_expensesFee = 0;
		_buybackFee = 0;
		_distributionFee = 0;
		_collateralFee = 0;
	}

	/**
	 * @notice Restores all fees removed previously, using cached variables.
	 */
	function restoreAllFee() internal {
		_taxFee = _previousTaxFee;
		_liquidityFee = _previousLiquidityFee;
		_expensesFee = _previousExpensesFee;
		_buybackFee = _previousBuybackFee;
		_distributionFee = _previousDistributionFee;
		_collateralFee = _previousCollateralFee;
	}

	function calculateTaxFee(
		uint256 amount,
		uint8 multiplier
	) internal view returns(uint256) {
		return amount.mul(_taxFee).mul(multiplier).div(10 ** 2);
	}

	function calculateLiquidityFee(
		uint256 amount,
		uint8 multiplier
	) internal view returns(uint256) {
		return amount.mul(_liquidityFee).mul(multiplier).div(10 ** 2);
	}

	function calculateExpensesFee(
		uint256 amount,
		uint8 multiplier
	) internal view returns(uint256) {
		return amount.mul(_expensesFee).mul(multiplier).div(10 ** 2);
	}

	function calculateBuybackFee(
		uint256 amount,
		uint8 multiplier
	) internal view returns(uint256) {
		return amount.mul(_buybackFee).mul(multiplier).div(10 ** 2);
	}

	function calculateDistributionFee(
		uint256 amount,
		uint8 multiplier
	) internal view returns(uint256) {
		return amount.mul(_distributionFee).mul(multiplier).div(10 ** 2);
	}

	function calculateCollateralFee(
		uint256 amount,
		uint8 multiplier
	) internal view returns(uint256) {
		return amount.mul(_collateralFee).mul(multiplier).div(10 ** 2);
	}

/* --------------------------- Triggers and limits -------------------------- */

	// Once contract accumulates 0.01% of total supply, trigger liquify.
	uint256 public minToLiquify = _tTotal.mul(1).div(10000);
	// One contract accumulates 0.01% of total supply, trigger expenses wallet sendout.
	uint256 public minToExpenses = _tTotal.mul(1).div(10000);
	// One contract accumulates 0.01% of total supply, trigger buyback.
	uint256 public minToBuyback = _tTotal.mul(1).div(10000);
	// One contract accumulates 0.01% of total supply, trigger rewards distribution.
	uint256 public minToDistribution = _tTotal.mul(1).div(10000);
	// One contract accumulates 0.01% of total supply, trigger collateral distribution.
	uint256 public minToCollateral = _tTotal.mul(1).div(10000);

	/**
	@notice External function allowing to set minimum amount of tokens which trigger
	* auto liquification.
	*/
	function setMinToLiquify(uint256 minTokens) 
		external 
		onlyOwner
		supplyBounds(minTokens)
	{
		minToLiquify = minTokens * 10 ** 5;
	}

	/**
	@notice External function allowing to set minimum amount of tokens which trigger
	* expenses send out.
	*/
	function setMinToExpenses(uint256 minTokens) 
		external 
		onlyOwner 
		supplyBounds(minTokens)
	{
		minToExpenses = minTokens * 10 ** 5;
	}

	/**
	@notice External function allowing to set minimum amount of tokens which trigger
	* buyback.
	*/
	function setMinToBuyback(uint256 minTokens) 
		external 
		onlyOwner 
		supplyBounds(minTokens)
	{
		minToBuyback = minTokens * 10 ** 5;
	}

	/**
	@notice External function allowing to set minimum amount of tokens which trigger
	* distribution.
	*/
	function setMinToDistribution(uint256 minTokens) 
		external 
		onlyOwner 
		supplyBounds(minTokens)
	{
		minToDistribution = minTokens * 10 ** 5;
	}

	/**
	@notice External function allowing to set minimum amount of tokens which trigger
	* collateral send out.
	*/
	function setMinToCollateral(uint256 minTokens) 
		external 
		onlyOwner 
		supplyBounds(minTokens)
	{
		minToCollateral = minTokens * 10 ** 5;
	}

/* --------------------------------- IERC20 --------------------------------- */
	function totalSupply() external pure override returns(uint256) {
		return _tTotal;
	}

	function totalFees() external view returns(uint256) { 
		return _tFeeTotal; 
	}

/* -------------------------------- Modifiers ------------------------------- */

	modifier supplyBounds(uint256 minTokens) {
		require(minTokens * 10 ** 5 > 0, "Amount must be more than 0");
		require(minTokens * 10 ** 5 <= _tTotal, "Amount must be not bigger than total supply");
		_;
	}
}