// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IOnwardIncentivesController {
	function handleAction(address _token, address _user, uint256 _balance, uint256 _totalSupply) external;
}
