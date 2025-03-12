// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ILockerList {
	function lockersCount() external view returns (uint256);

	function getUsers(uint256 page, uint256 limit) external view returns (address[] memory);

	function addToList(address user) external;

	function removeFromList(address user) external;
}
