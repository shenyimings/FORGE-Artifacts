// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;
pragma experimental ABIEncoderV2;

interface ILockZap {
	function zap(
		bool _borrow,
		uint256 _wethAmt,
		uint256 _rdntAmt,
		uint256 _lockTypeIndex
	) payable external returns (uint256 liquidity);

	function zapOnBehalf(
		bool _borrow,
		uint256 _wethAmt,
		uint256 _rdntAmt,
		address _onBehalf
	) payable external returns (uint256 liquidity);

	function quoteFromToken(uint256 _tokenAmount) external view returns (uint256 optimalWETHAmount);
}