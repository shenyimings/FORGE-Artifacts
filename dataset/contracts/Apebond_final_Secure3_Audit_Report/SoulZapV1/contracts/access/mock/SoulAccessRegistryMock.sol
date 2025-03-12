// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SoulAccessManaged} from "../SoulAccessManaged.sol"; // Import the SoulAccessManaged contract or interface

contract SoulAccessRegistryMock is SoulAccessManaged {
    uint256 public somethingSensitiveCount = 0;

    constructor(address _accessRegistryAddress) SoulAccessManaged(_accessRegistryAddress) {}

    function doSomethingSensitive() external onlyAccessRegistryRoleName("SOUL_ACCESS_REGISTRY_ROLE") {
        somethingSensitiveCount++;
    }
}
