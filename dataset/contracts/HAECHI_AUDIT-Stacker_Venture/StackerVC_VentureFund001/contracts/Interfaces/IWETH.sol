// SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;

interface IWETH {	
	function deposit() payable external;
	function withdraw(uint256 wad) external;
}
