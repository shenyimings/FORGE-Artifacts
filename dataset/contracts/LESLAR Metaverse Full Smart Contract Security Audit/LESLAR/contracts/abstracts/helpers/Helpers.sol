// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

abstract contract Helpers {

/* -------------------------------- Modifiers ------------------------------- */

	modifier legitWallet(address wallet) {
		require(wallet != address(0), "Wallet address must be set!");
		require(wallet != address(this), "Wallet address can't be this contract.");
		_;
	}
}