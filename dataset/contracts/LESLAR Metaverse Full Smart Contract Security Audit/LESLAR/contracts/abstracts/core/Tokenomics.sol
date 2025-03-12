// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Tokenomics is IERC20, Ownable {
	using SafeMath for uint256;
    mapping (address => bool) private _isBot;

/* ---------------------------------- Token --------------------------------- */

	string internal constant NAME = "LESLAR Metaverse";
	string internal constant SYMBOL = "LESLAR";

	uint8 internal constant DECIMALS = 9;
	uint256 internal constant ZEROES = 10 ** DECIMALS;

	uint256 private constant MAX = ~uint256(0);
	uint256 internal constant _tTotal = 1000000000000 * ZEROES;
	uint256 internal _rTotal = (MAX - (MAX % _tTotal));

	address public deadAddr = 0x000000000000000000000000000000000000dEaD;

/* ---------------------------------- Fees ---------------------------------- */

	// To be collected for tax
	uint256 public _taxFee = 3;
	// Used to cache fee when removing fee temporarily.
	uint256 internal _previousTaxFee = _taxFee;
	// Will keep tabs on the amount which should be taken from wallet for taxes.
	uint256 public accumulatedForTax = 0;

	/**
	 * @notice Allows setting Tax fee.
	 */
	function setTaxFee(uint256 fee)
		external 
		onlyOwner
		sameValue(_taxFee, fee)
	{
		_taxFee = fee;
	}

	/**
	 * @notice Allows temporarily set all feees to 0. 
	 * It can be restored later to the previous fees.
	 */
	function disableAllFeesTemporarily()
		external
		onlyOwner
	{
		removeAllFee();
	}

	/**
	 * @notice Restore all fees from previously set.
	 */
	function restoreAllFees()
		external
		onlyOwner
	{
		restoreAllFee();
	}

	/**
	 * @notice Temporarily stops all fees. Caches the fees into secondary variables,
	 * so it can be reinstated later.
	 */
	function removeAllFee() internal {
		if (_taxFee == 0) return;

		_previousTaxFee = _taxFee;

		_taxFee = 0;
	}

	/**
	 * @notice Restores all fees removed previously, using cached variables.
	 */
	function restoreAllFee() internal {
		_taxFee = _previousTaxFee;
	}

	function calculateTaxFee(
		uint256 amount,
		uint8 multiplier
	) internal view returns(uint256) {
		return amount.mul(_taxFee).mul(multiplier).div(10 ** 2);
	}

/* --------------------------- Triggers and limits -------------------------- */

	// One contract accumulates 0.01% of total supply, trigger tax wallet sendout.
	uint256 public minToTax = _tTotal.mul(1).div(10000);

	/**
	@notice External function allowing to set minimum amount of tokens which trigger
	* tax send out.
	*/
	function setMinToTax(uint256 minTokens) 
		external 
		onlyOwner 
		supplyBounds(minTokens)
	{
		minToTax = minTokens * 10 ** 5;
	}

/* --------------------------------- IERC20 --------------------------------- */
	function totalSupply() external pure override returns(uint256) {
		return _tTotal;
	}

	function totalFees() external view returns(uint256) { 
		return _taxFee; 
	}

/* ---------------------------- Anti Bot System --------------------------- */

    function setAntibot(address account, bool _bot) external onlyOwner{
        require(_isBot[account] != _bot, "Value already set");
        _isBot[account] = _bot;
    }

    function isBot(address account) public view returns(bool){
        return _isBot[account];
    }

/* -------------------------------- Modifiers ------------------------------- */

    // Use this in case BNB are sent to the contract by mistake
    function rescueBNB(uint256 weiAmount) external onlyOwner{
        require(address(this).balance >= weiAmount, "insufficient BNB balance");
        payable(msg.sender).transfer(weiAmount);
    }

    function rescueBEP20Tokens(address tokenAddress) external onlyOwner{
        IERC20(tokenAddress).transfer(msg.sender, IERC20(tokenAddress).balanceOf(address(this)));
    }

/* -------------------------------- Modifiers ------------------------------- */

	modifier supplyBounds(uint256 minTokens) {
		require(minTokens * 10 ** 5 > 0, "Amount must be more than 0");
		require(minTokens * 10 ** 5 <= _tTotal, "Amount must be not bigger than total supply");
		_;
	}

	modifier sameValue(uint256 firstValue, uint256 secondValue) {
		require(firstValue != secondValue, "Already set to this value.");
		_;
	}
}