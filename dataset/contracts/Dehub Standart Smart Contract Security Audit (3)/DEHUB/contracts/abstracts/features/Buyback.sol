// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../core/Tokenomics.sol";
import "../core/Pancake.sol";
import "../core/RFI.sol";
import "../helpers/Helpers.sol";
import "../features/TxPolice.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Buyback is Ownable, Helpers, Tokenomics, Pancake, RFI, TxPolice {
	using SafeMath for uint256;
	// Will keep tabs on how much BNB from the balance belongs for buyback
	uint256 public bnbAccumulatedForBuyback;

	/** 
	* @notice Checks if all required prerequisites are met for us to trigger 
	* selling of the tokens for later buyback.
	*/
	function canSellForBuyback(
		uint256 contractTokenBalance
	) 
		internal
		view
		returns(bool) 
	{
		return contractTokenBalance >= accumulatedForBuyback 
			&& accumulatedForBuyback >= minToBuyback;
	}

	/**
	* @notice Sells tokens accumulated for buyback. Receives BNB. 
	* Updates the BNB accumulator so we know how much to use for buyback later.
	* NOTE: needs to be tested on testnet!!!
	* @param tokenAmount amount of tokens to take from balance and sell.
	*/
	function sellForBuyback(
		uint256 tokenAmount
	) internal lockTheProcess {
		// Must approve before swapping.
		rfiApprove(address(this), address(uniswapV2Router), tokenAmount);
		uint256 bnbReceived = swapTokensForBnb(tokenAmount);
		// Increment BNB accumulator
		bnbAccumulatedForBuyback = bnbAccumulatedForBuyback.add(bnbReceived);
		// Reset tokens accumulator
		accumulatedForBuyback = 0;
		emit SoldTokensForBuyback(tokenAmount, bnbReceived);
	}

	/**
	* @notice External function, which when called. Will attempt to sell requested 
	* amount of BNB and will send received tokens to a dead address immediately.
	* NOTE: don't forget that bnbAmount passed should be * 10 ** 18
	*/
	function buyback(uint256 bnbAmount) 
		external
		onlyOwner
		onlyIfEnoughBNBAccumulated(bnbAmount, bnbAccumulatedForBuyback)
	{
		address[] memory path = new address[](2);
		path[0] = uniswapV2Router.WETH();
		path[1] = address(this);

		// Make the swap and send to dead address
		uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: bnbAmount}(
			0,
			path,
			deadAddr,
			block.timestamp
		);

		// Decrement bnb accumulator
		bnbAccumulatedForBuyback = bnbAccumulatedForBuyback.sub(bnbAmount);

		emit BuybackDone(bnbAmount);
	}

/* --------------------------------- Events --------------------------------- */
	event SoldTokensForBuyback(
		uint256 tokensSold,
		uint256 bnbReceived
	);

	event BuybackDone(
		uint256 bnbUsed
	);
}