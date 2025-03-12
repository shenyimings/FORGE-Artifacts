// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract SetCapacityScript is BaseScript {
  function run() public {
    address vaultToken = 0x5dc672d3528535a97173AeD4671ccd2E5f627e44;
    uint32 newCapacity = type(uint32).max;

    vm.startBroadcast(deployerPrivateKey);

    AutomatedVaultManager(automatedVaultManager).setCapacity(vaultToken, newCapacity);

    vm.stopBroadcast();
  }
}
