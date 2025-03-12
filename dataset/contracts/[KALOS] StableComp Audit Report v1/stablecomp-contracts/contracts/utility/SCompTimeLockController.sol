// SPDX-License-Identifier: ISC

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract SCompTimeLockController is TimelockController {

    constructor(uint _minDelay, address[] memory proposer, address[] memory executors) TimelockController(_minDelay, proposer, executors)
    {}

}
