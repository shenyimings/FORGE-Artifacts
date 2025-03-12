// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../core/Tokenomics.sol";
import "../core/RFI.sol";
import "../core/Pancake.sol";
import "../features/TxPolice.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

abstract contract Liquify is Tokenomics, Pancake, RFI, TxPolice {
	using SafeMath for uint256;

	/** 
	* @notice Checks if all required prerequisites are met for us to trigger 
	* liquidity event.
	*/
	function canLiquify(
		uint256 contractTokenBalance
	) 
		internal 
		view
		returns(bool) 
	{
		return contractTokenBalance >= accumulatedForLiquidity 
			&& accumulatedForLiquidity >= minToLiquify;
	}

	function addInitialLiquidity(
		uint256 tokenAmount,
		uint256 bnbAmount
	) external onlyOwner {
		addLiquidity(tokenAmount, bnbAmount, true);
	}

	/**
	 * @notice Adds LP to Pancakeswap using it's router.
	 * @param tokenAmount Token amount for LP.
	 * @param bnbAmount BNB amount for LP.
	 */
	function addLiquidity(
		uint256 tokenAmount,
		uint256 bnbAmount,
		bool firstTime
	) internal pcsInitialized {

		uint256 amountTokenMin;
		uint256 amountEthMin;
		if (firstTime) {
			amountTokenMin = tokenAmount;
			amountEthMin = bnbAmount;
		}

		// Approve token transfer to cover all possible scenarios
		rfiApprove(address(this), address(uniswapV2Router), tokenAmount);

		// Add the liquidity
		uniswapV2Router.addLiquidityETH {
			value: bnbAmount
		}(
			address(this),
			tokenAmount,
			amountTokenMin,
			amountEthMin,
			owner(),
			block.timestamp
		);

		if (firstTime) {
			IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);
		}
	}

	/**
	 * @notice Swaps a piece of tokens for BNB and uses it to add liquidity to PCS.
	 * @param tokenAmount Min amount of tokens from contract that will be swapped.
	 * NOTE: needs to be tested on testnet!!!
	 */
	function swapAndLiquify(
		uint256 tokenAmount
	) internal lockTheProcess {
		// Split tokens for liquidity.
		uint256 half = tokenAmount.div(2);
		uint256 otherHalf = tokenAmount.sub(half);
		// Swap and get how much BNB received.
		// Must approve before swapping.
		rfiApprove(address(this), address(uniswapV2Router), tokenAmount);
		uint256 bnbReceived = swapTokensForBnb(half);
		// Add liquidity to pancake
		addLiquidity(otherHalf, bnbReceived, false);
		// Reset the accumulator
		accumulatedForLiquidity = 0;
		emit SwapAndLiquify(half, bnbReceived, otherHalf);
	}

/* --------------------------------- Events --------------------------------- */

	event SwapAndLiquify(
		uint256 tokensSwapped,
		uint256 ethReceived,
		uint256 tokensIntoLiquidity
	);
}