// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../helpers/Helpers.sol";
import "../core/Pancake.sol";
import "../core/Tokenomics.sol";
import "../features/TxPolice.sol";

abstract contract Expensify is Ownable, Helpers, Tokenomics, Pancake, TxPolice {
	using SafeMath for uint256;
	address public productDevWallet;
	address public devWallet;
	address public marketingWallet;
	// Expenses fee accumulated amount will be divided using these.
	uint256 public productDevShare = 30; // 30%
	uint256 public devShare = 30; // 30%
	uint256 public marketingShare = 40; // 40%

	/**
	* @notice External function allowing to set/change product dev wallet.
	* @param wallet: this wallet will receive product dev share.
	* @param share: multiplier will be divided by 100. 30 -> 30%, 3 -> 3% etc.
	*/
	function setProductDevWallet(address wallet, uint256 share) 
		external onlyOwner legitWallet(wallet) 
	{
		productDevWallet = wallet;
		productDevShare = share;
		swapExcludedFromFee(wallet, productDevWallet);
	}

	/**
	* @notice External function allowing to set/change dev wallet.
	* @param wallet: this wallet will receive dev share.
	* @param share: multiplier will be divided by 100. 30 -> 30%, 3 -> 3% etc.
	*/
	function setDevWallet(address wallet, uint256 share) 
		external onlyOwner legitWallet(wallet)
	{
		devWallet = wallet;
		devShare = share;
		swapExcludedFromFee(wallet, devWallet);
	}

	/**
	* @notice External function allowing to set/change marketing wallet.
	* @param wallet: this wallet will receive marketing share.
	* @param share: multiplier will be divided by 100. 30 -> 30%, 3 -> 3% etc.
	*/
	function setMarketingWallet(address wallet, uint256 share) 
		external onlyOwner legitWallet(wallet)
	{
		marketingWallet = wallet;
		marketingShare = share;
		swapExcludedFromFee(wallet, marketingWallet);
	}

	/** 
	* @notice Checks if all required prerequisites are met for us to trigger 
	* taxes send out event.
	*/
	function canTax(
		uint256 contractTokenBalance
	) 
		internal 
		view
		returns(bool) 
	{
		return contractTokenBalance >= accumulatedForTax
            && accumulatedForTax >= minToTax;
	}

	/**
	* @notice Splits tokens into pieces for product dev, dev and marketing wallets 
	* and sends them out.
	* Note: Shares must add up to 100, otherwise tax fee will not be 
		distributed properly. And that can invite many other issues.
		So we can't proceed. You will see "Taxify" event triggered on 
		the blockchain with "0, 0, 0" then. This will guide you to check and fix
		your share setup.
		Wallets must be set. But we will not use "require", so not to trigger 
		transaction failure just because someone forgot to set up the wallet 
		addresses. If you see "Taxify" event with "0, 0, 0" values, then 
		check if you have set the wallets.
		@param tokenAmount amount of tokens to take from balance and send out.
	*/
	function taxify(
		uint256 tokenAmount
	) internal lockTheProcess {
		uint256 productDevPiece;
		uint256 devPiece;
		uint256 marketingPiece;

		if (
			productDevShare.add(devShare).add(marketingShare) == 100
			&& productDevWallet != address(0) 
			&& devWallet != address(0)
			&& marketingWallet != address(0)
		) {
			productDevPiece = tokenAmount.mul(productDevShare).div(100);
			devPiece = tokenAmount.mul(devShare).div(100);
			// Make sure all tokens are distributed.
			marketingPiece = tokenAmount.sub(productDevPiece).sub(devPiece);
			_transfer(address(this), productDevWallet, productDevPiece);
			_transfer(address(this), devWallet, devPiece);
			_transfer(address(this), marketingWallet, marketingPiece);
			// Reset the accumulator, only if tokens actually sent, otherwise we keep
			// acumulating until above mentioned things are fixed.
			accumulatedForTax = 0;
		}
		
 		emit TaxifyDone(productDevPiece, devPiece, marketingPiece);
	}

/* --------------------------------- Events --------------------------------- */
	event TaxifyDone(
		uint256 tokensSentToProductDev,
		uint256 tokensSentToDev,
		uint256 tokensSentToMarketing
	);
}