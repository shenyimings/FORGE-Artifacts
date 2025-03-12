// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../helpers/Helpers.sol";
import "../core/Pancake.sol";
import "../core/RFI.sol";
import "../features/TxPolice.sol";
import "../core/Tokenomics.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

abstract contract Collateralize is Ownable, Helpers, Tokenomics, Pancake, RFI, TxPolice {
	using SafeMath for uint256;
	// Wallet which will receive BNB tokens for collateral.
	address payable public collateralWallet;
	// Will keep tabs on how much BNB from the balance belongs for collateral.
	uint256 public bnbAccumulatedForCollateral;

	/**
	* @notice External function allowing to set/change collateral wallet.
	* @param wallet: this wallet will receive collateral BNB.
	*/
	function setCollateralWallet(address wallet) 
		external onlyOwner legitWallet(wallet)
	{
		collateralWallet = payable(wallet);
		swapExcludedFromFee(wallet, collateralWallet);
	}

	/** 
	* @notice Checks if all required prerequisites are met for us to trigger 
	* selling of the tokens for later collateralization.
	*/
	function canSellForCollateral(
		uint256 contractTokenBalance
	) 
		internal 
		view
		returns(bool) 
	{
		return contractTokenBalance >= accumulatedForCollateral 
			&& accumulatedForCollateral >= minToCollateral;
	}

	/**
	* @notice Sells tokens accumulated for collateral. Receives BNB.
	* Updates the BNB accumulator so we know how much to use for collateralize later.
	* @param tokenAmount amount of tokens to take from balance and sell.
	* NOTE: needs to be tested on testnet!!!
	* Note: Wallet must be set. But we will not use "require", so not to trigger 
		transaction failure just because someone forgot to set up the wallet address. 
		If you see "SoldTokensForCollateral" event with "0, 0" values, then check if 
		you have set the wallet.
	*/
	function sellForCollateral(
		uint256 tokenAmount
	) internal lockTheProcess {
		uint256 tokensSold;
		uint256 bnbReceived;

		if (collateralWallet != address(0)) {
			// Must approve before swapping.
			rfiApprove(address(this), address(uniswapV2Router), tokenAmount);
			bnbReceived = swapTokensForBnb(tokenAmount);
			tokensSold = tokenAmount;
			// Increment BNB accumulator
			bnbAccumulatedForCollateral = bnbAccumulatedForCollateral.add(bnbReceived);
			// Reset the accumulator, only if tokens actually sold, otherwise we keep
			// acumulating until collateral wallet is set.
			accumulatedForCollateral = 0;
		}
		emit SoldTokensForCollateral(tokensSold, bnbReceived);
	}

	/**
	* @notice External function, which when called. Will attempt to transfer 
	* requested of BNB to collateral wallet.
	* NOTE: don't forget that bnbAmount passed should be * 10 ** 18
	*/
	function collateralize(uint256 bnbAmount)
		external
		onlyOwner
		onlyIfEnoughBNBAccumulated(bnbAmount, bnbAccumulatedForCollateral)
	{
		collateralWallet.transfer(bnbAmount);
		// Decrement bnb accumulator
		bnbAccumulatedForCollateral = bnbAccumulatedForCollateral.sub(bnbAmount);
		emit CollateralizeDone(bnbAmount);
	}

/* --------------------------------- Events --------------------------------- */
	event SoldTokensForCollateral(
		uint256 tokensSold,
		uint256 bnbReceived
	);

	event CollateralizeDone(
		uint256 bnbUsed
	);
}