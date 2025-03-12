// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Tokenomics.sol";
import "./RFI.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

abstract contract Supply is Tokenomics, RFI {
	using SafeMath for uint256;
	/**
	 * @notice Calculates current total circulating supply by substracting "burned"
	 * tokens.
	 */
	function totalCirculatingSupply() public view returns(uint256) {
		return _tTotal.sub(balanceOf(deadAddr));
	}
}