// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin_v2_5_0/Roles.sol";
import "./LuciDaoSale.sol";


contract LucidaoPublicSale is LucidaoSale, Ownable {
	using Roles for Roles.Role;

	address[] private emptyList;

	modifier onlyWhileBeforeOpen() {
		require(isBeforeOpen(), "Sale already started");
		_;
	}

	constructor(
		uint256 _rate,
		uint256 _cap,
		address _treasuryWallet,
		IERC20 _token,
		IERC20 _buyToken,
		uint256 _openingTime,
		uint256 _closingTime,
		uint256 _tokensForSale
	) LucidaoSale(_rate, _cap, _treasuryWallet, _token, _buyToken, _openingTime, _closingTime, _tokensForSale, emptyList){
	}

	function addToWhitelist(address whitelistedAddress) external onlyOwner onlyWhileBeforeOpen {
		_whitelisted.add(whitelistedAddress);
	}
}