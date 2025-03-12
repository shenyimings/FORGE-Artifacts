// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../core/Tokenomics.sol";
import "../core/Pancake.sol";


abstract contract RFI is IERC20, Ownable, Tokenomics, Pancake {
	using SafeMath for uint256;

	mapping(address => uint256) internal _rOwned;
	mapping(address => uint256) internal _tOwned;
	mapping(address => mapping(address => uint256)) private _allowances;

	struct TValues {
		uint256 tTransferAmount;
		uint256 tFee;
		uint256 tLiquidity;
		uint256 tExpenses;
		uint256 tBuyback;
		uint256 tDistribution;
		uint256 tCollateral;
	}

	struct RValues {
		uint256 rAmount;
		uint256 rTransferAmount;
		uint256 rFee;
	}

	constructor() {
		// Assigns all reflected tokens to the deployer on creation
		_rOwned[_msgSender()] = _rTotal;

		emit Transfer(address(0), _msgSender(), _tTotal);
	}

	/**
	 * @notice Calculates all values for "total" and "reflected" states.
	 * @param tAmount Token amount related to which, all values are calculated.
	 */
	function _getValues(
		uint256 tAmount
	) private view returns(
		TValues memory tValues, RValues memory rValues
	) {
		TValues memory tV = _getTValues(tAmount);
		RValues memory rV = _getRValues(
			tAmount,
			tV.tFee,
			tV.tLiquidity,
			tV.tExpenses,
			tV.tBuyback,
			tV.tDistribution,
			tV.tCollateral,
			_getRate()
		);
		return (tV, rV);
	}

	/**
	 * @notice Calculates values for "total" states.
	 * @param tAmount Token amount related to which, total values are calculated.
	 */
	function _getTValues(
		uint256 tAmount
	) private view returns(TValues memory tValues) {
		TValues memory tV;
		tV.tFee = calculateTaxFee(tAmount, 1);
		tV.tLiquidity = calculateLiquidityFee(tAmount, 1);
		tV.tExpenses = calculateExpensesFee(tAmount, 1);
		tV.tBuyback = calculateBuybackFee(tAmount, 1);
		tV.tDistribution = calculateDistributionFee(tAmount, 1);
		tV.tCollateral = calculateCollateralFee(tAmount, 1);






		uint256 fees = tV.tFee
			.add(tV.tLiquidity)
			.add(tV.tExpenses)
			.add(tV.tBuyback)
			.add(tV.tDistribution)
			.add(tV.tCollateral);
		tV.tTransferAmount = tAmount.sub(fees);
		return tV;
	}

	/**
	 * @notice Calculates values for "reflected" states.
	 * @param tAmount Token amount related to which, reflected values are calculated.
	 * @param tFee Total fee related to which, reflected values are calculated.
	 * @param tLiquidity Total liquidity related to which, reflected values are calculated.
	 * @param currentRate Rate used to calculate reflected values.
	 */
	function _getRValues(
		uint256 tAmount,
		uint256 tFee,
		uint256 tLiquidity,
		uint256 tExpenses,
		uint256 tBuyback,
		uint256 tDistribution,
		uint256 tCollateral,
		uint256 currentRate
	) private pure returns(RValues memory rValues) {
		RValues memory rV;
		rV.rAmount = tAmount.mul(currentRate);
		rV.rFee = tFee.mul(currentRate);
		uint256 rLiquidity = tLiquidity.mul(currentRate);
		uint256 rExpenses = tExpenses.mul(currentRate);
		uint256 rBuyback = tBuyback.mul(currentRate);
		uint256 rDistribution = tDistribution.mul(currentRate);
		uint256 rCollateral = tCollateral.mul(currentRate);
		uint256 fees = rV.rFee + rLiquidity + rExpenses + rBuyback + rDistribution + rCollateral;
		rV.rTransferAmount = rV.rAmount.sub(fees);
		return rV;
	}

	/**
	 * @notice Calculates the rate of total suply to reflected supply.
	 */
	function _getRate() private view returns(uint256) {
		(uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
		return rSupply.div(tSupply);
	}

	function _reflectFee(
		uint256 rFee,
		uint256 tFee
	) private {
		_rTotal = _rTotal.sub(rFee);
		_tFeeTotal = _tFeeTotal.add(tFee);
	}

	/**
	 * @notice Returns totals for "total" supply and "reflected" supply.
	 */
	function _getCurrentSupply() private view returns(uint256, uint256) {
		uint256 rSupply = _rTotal;
		uint256 tSupply = _tTotal;
		if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
		return (rSupply, tSupply);
	}

	function reflectionFromToken(
		uint256 tAmount,
		bool deductTransferFee
	) public view returns(uint256) {
		require(tAmount <= _tTotal, "Amount must be less than supply");
		(, RValues memory rV) = _getValues(tAmount);
		if (!deductTransferFee) {
			return rV.rAmount;
		} else {
			return rV.rTransferAmount;
		}
	}

	function tokenFromReflection(
		uint256 rAmount
	) public view returns(uint256) {
		require(rAmount <= _rTotal, "Amount must be less than total reflections");
		uint256 currentRate = _getRate();
		return rAmount.div(currentRate);
	}

/* --------------------------------- Custom --------------------------------- */

	/**
	 * @notice ERC20 token transaction approval with allowance.
	 */
	function rfiApprove(
		address ownr,
		address spender,
		uint256 amount
	) internal {
		require(ownr != address(0), "ERC20: approve from the zero address");
		require(spender != address(0), "ERC20: approve to the zero address");

		_allowances[ownr][spender] = amount;
		emit Approval(ownr, spender, amount);
	}

	function _transfer(
		address from,
		address to,
		uint256 amount
	) internal {
		require(from != address(0), "ERC20: transfer from the zero address");
		require(to != address(0), "ERC20: transfer to the zero address");
		require(amount > 0, "Transfer amount must be greater than zero");

		// Override this in the main contract to plug your features inside transactions.
		beforeTokenTransfer(from, to, amount);

		// Transfer amount, it will take tax, liquidity fee
		bool take = takeFee(from, to);
		_tokenTransfer(from, to, amount, take);
	}

	/**
	 * @notice Performs token transfer with fees.
	 * @param sender Address of the sender.
	 * @param recipient Address of the recipient.
	 * @param amount Amount of tokens to send.
	 * @param take Toggle on/off fees.
	 */
	function _tokenTransfer(
		address sender,
		address recipient,
		uint256 amount,
		bool take
	) private {

		// Remove fees for this transaction if needed.
		if (!take)
			removeAllFee();

		// Calculate all reflection magic...
		(TValues memory tV, RValues memory rV) = _getValues(amount);

		// Adjust reflection states
		_rOwned[sender] = _rOwned[sender].sub(rV.rAmount);
		_rOwned[recipient] = _rOwned[recipient].add(rV.rTransferAmount);

		// Calcuate fees. If above fees were removed, then these will obviously
		// not take any fees.
		_takeLiquidityFee(tV.tLiquidity);
		_takeExpensesFee(tV.tExpenses);
		_takeBuybackFee(tV.tBuyback);
		_takeDistributionFee(tV.tDistribution);
		_takeCollateralFee(tV.tCollateral);
		_reflectFee(rV.rFee, tV.tFee);

		emit Transfer(sender, recipient, tV.tTransferAmount);

		// Reinstate fees if they were removed for this transaction.
		if (!take)
			restoreAllFee();
	}

	/**
	* @notice Override this function to intercept the transaction and perform 
	* additional checks or perform certain functions before allowing transaction
	* to complete. You can prevent transaction to complete here too.
	*/
	function beforeTokenTransfer(
		address from, 
		address to, 
		uint256 amount
	) virtual internal {


	}

	function takeFee(address from, address to) virtual internal returns(bool) {


		return true;
	}

/* ------------------------------- Custom fees ------------------------------ */
	/**
	* @notice Collects tokens from liquidity fee. Accordingly adjusts "reflected" 
	amounts. 
	*/
	function _takeLiquidityFee(
		uint256 tLiquidity
	) private {
		uint256 currentRate = _getRate();
		uint256 rLiquidity = tLiquidity.mul(currentRate);
		_rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
		// Keep tabs, so when processing is triggered, we know how much should we take.
		accumulatedForLiquidity = accumulatedForLiquidity.add(tLiquidity);
	}

	/**
	* @notice Collects tokens from expeneses fee. Accordingly adjusts "reflected" 
	amounts. 
	*/
	function _takeExpensesFee(
		uint256 tExpenses
	) private {
		uint256 currentRate = _getRate();
		uint256 rExpenses = tExpenses.mul(currentRate);
		_rOwned[address(this)] = _rOwned[address(this)].add(rExpenses);
		// Keep tabs, so when processing is triggered, we know how much should we take.
		accumulatedForExpenses = accumulatedForExpenses.add(tExpenses);
	}

	/**
	* @notice Collects tokens from buyback fee. Accordingly adjusts "reflected" 
	amounts. 
	*/
	function _takeBuybackFee(
		uint256 tBuyback
	) private {
		uint256 currentRate = _getRate();
		uint256 rBuyback = tBuyback.mul(currentRate);
		_rOwned[address(this)] = _rOwned[address(this)].add(rBuyback);
		// Keep tabs, so when processing is triggered, we know how much should we take.
		accumulatedForBuyback = accumulatedForBuyback.add(tBuyback);
	}

	/**
	* @notice Collects tokens from distribution fee. Accordingly adjusts "reflected" 
	amounts. 
	*/
	function _takeDistributionFee(
		uint256 tDistribution
	) private {
		uint256 currentRate = _getRate();
		uint256 rDistribution = tDistribution.mul(currentRate);
		_rOwned[address(this)] = _rOwned[address(this)].add(rDistribution);
		// Keep tabs, so when processing is triggered, we know how much should we take.
		accumulatedForDistribution = accumulatedForDistribution.add(tDistribution);
	}

		/**
	* @notice Collects tokens from collateral fee. Accordingly adjusts "reflected" 
	amounts. 
	*/
	function _takeCollateralFee(
		uint256 tCollateral
	) private {
		uint256 currentRate = _getRate();
		uint256 rCollateral = tCollateral.mul(currentRate);
		_rOwned[address(this)] = _rOwned[address(this)].add(rCollateral);
		// Keep tabs, so when processing is triggered, we know how much should we take.
		accumulatedForCollateral = accumulatedForCollateral.add(tCollateral);
	}

/* --------------------------------- IERC20 --------------------------------- */

	function balanceOf(
		address account
	) public view override returns(uint256) {
		return tokenFromReflection(_rOwned[account]);
	}

	function transfer(
		address recipient,
		uint256 amount
	) public override returns(bool) {
		_transfer(_msgSender(), recipient, amount);
		return true;
	}

	function allowance(
		address ownr,
		address spender
	) public view override returns(uint256) {
		return _allowances[ownr][spender];
	}

	function approve(
		address spender,
		uint256 amount
	) public override returns(bool) {
		rfiApprove(_msgSender(), spender, amount);
		return true;
	}

	function transferFrom(
		address sender,
		address recipient,
		uint256 amount
	) public override returns(bool) {
		_transfer(sender, recipient, amount);
		rfiApprove(
			sender,
			_msgSender(),
			_allowances[sender][_msgSender()].sub(
				amount,
				"ERC20: transfer amount exceeds allowance"
			)
		);
		return true;
	}

	function increaseAllowance(
		address spender,
		uint256 addedValue
	) public virtual returns(bool) {
		rfiApprove(
			_msgSender(),
			spender,
			_allowances[_msgSender()][spender].add(addedValue)
		);
		return true;
	}

	function decreaseAllowance(
		address spender,
		uint256 subtractedValue
	) public virtual returns(bool) {
		rfiApprove(
			_msgSender(),
			spender,
			_allowances[_msgSender()][spender]
			.sub(subtractedValue, "ERC20: decreased allowance below zero")
		);
		return true;
	}

/* -------------------------------- Modifiers ------------------------------- */

	modifier onlyOwnerOrHolder {
		require(
			owner() == _msgSender() || balanceOf(_msgSender()) > 0, 
			"Only owner and holders can use this feature."
			);
		_;
	}

	modifier onlyHolder {
		require(
			balanceOf(_msgSender()) > 0, 
			"Only holders can use this feature."
			);
		_;
	}
}