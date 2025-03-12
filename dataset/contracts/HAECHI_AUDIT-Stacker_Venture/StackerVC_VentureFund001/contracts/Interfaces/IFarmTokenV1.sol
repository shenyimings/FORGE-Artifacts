// SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;

interface IFarmTokenV1 {
	function name() external view returns (string memory);
	function symbol() external view returns (string memory);
	function decimals() external view returns (uint8);
	function getSharesForUnderlying(uint256 _amountUnderlying) external view returns (uint256);
	function getUnderlyingForShares(uint256 _amountShares) external view returns (uint256);
}