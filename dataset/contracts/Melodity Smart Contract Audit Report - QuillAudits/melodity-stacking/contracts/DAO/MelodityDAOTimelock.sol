// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract MelodityDAOTimelock is TimelockController {
	/**
		initialize with:
		MelodityDAOTimelock([], [address(0)])
	 */
	constructor(address[] memory _proposers, address[] memory _executors) 
	TimelockController(
		84 hours, 			// 3.5 days
		_proposers, 		// proposers
		_executors			// everyone can trigger the execution
	 ) {}
}