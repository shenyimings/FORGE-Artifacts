// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;


interface IBootstrapBallot
	{
	function vote( bool voteStartExchangeYes, uint256[] memory votesRegionalExclusions, bytes memory signature  ) external;
	function finalizeBallot() external;

	// Views
	function completionTimestamp() external returns (uint256);
	function hasVoted(address user) external returns (bool);

	function ballotFinalized() external returns (bool);
	function startExchangeApproved() external returns (bool);

	function startExchangeYes() external returns (uint256);
	function startExchangeNo() external returns (uint256);

	function geoExclusionYes() external returns (uint256[] memory);
	function geoExclusionNo() external returns (uint256[] memory);
	}
