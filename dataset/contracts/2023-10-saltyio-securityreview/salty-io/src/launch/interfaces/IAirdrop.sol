// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;


interface IAirdrop
	{
	function authorizeWallet( address wallet ) external;
	function allowClaiming() external;
	function claimAirdrop() external;

	// Views
	function saltAmountForEachUser() external returns (uint256);
	function claimingAllowed() external returns (bool);
	function claimed(address wallet) external returns (bool);

	function isAuthorized(address wallet) external returns (bool);
	function numberAuthorized() external returns (uint256);
	function authorizedWallets() external view returns (address[] calldata);
	}
