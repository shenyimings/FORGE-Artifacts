// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;



abstract contract Helpers {

/* -------------------------------- Modifiers ------------------------------- */

	modifier legitWallet(address wallet) {
		require(wallet != address(0), "Wallet address must be set!");
		require(wallet != address(this), "Wallet address can't be this contract.");
		_;
	}

	modifier onlyIfEnoughBNBAccumulated(uint256 bnbRequested, uint256 bnbAccumulator) {
		require(bnbRequested <= bnbAccumulator, "Not enough BNB accumulated.");
		// This should not ever happen...
		require(bnbRequested <= address(this).balance, "Not enough BNB in the wallet.");
		_;
	}
}