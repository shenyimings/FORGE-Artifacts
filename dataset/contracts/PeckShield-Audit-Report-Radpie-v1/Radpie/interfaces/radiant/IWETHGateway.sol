// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IWETHGateway {
	function depositETH(address lendingPool, address onBehalfOf, uint16 referralCode) external payable;

	function withdrawETH(address lendingPool, uint256 amount, address onBehalfOf) external;

	function repayETH(address lendingPool, uint256 amount, uint256 rateMode, address onBehalfOf) external payable;

	function borrowETH(address lendingPool, uint256 amount, uint256 interesRateMode, uint16 referralCode) external;
}
