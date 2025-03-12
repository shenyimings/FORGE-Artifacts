// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IBountyManager {
	function quote(address _param) external returns (uint256 bounty);

	function claim(address _param) external returns (uint256 bounty);

	function minDLPBalance() external view returns (uint256 amt);
}
