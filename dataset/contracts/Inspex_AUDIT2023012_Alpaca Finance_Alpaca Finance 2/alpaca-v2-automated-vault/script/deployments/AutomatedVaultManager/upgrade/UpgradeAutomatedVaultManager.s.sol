// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/proxy/transparent/ProxyAdmin.sol";

contract UpgradeAutomatedVaultManagerScript is BaseScript {
  function run() public {
    vm.startBroadcast(deployerPrivateKey);

    // Deploy implementation
    address automatedVaultManagerImplementation = address(new AutomatedVaultManager());

    // Upgrade proxy to new implementation
    ProxyAdmin(proxyAdmin).upgrade(
      ITransparentUpgradeableProxy(payable(automatedVaultManager)), automatedVaultManagerImplementation
    );

    vm.stopBroadcast();

    _writeJson(vm.toString(automatedVaultManagerImplementation), ".automatedVault.automatedVaultManager.implementation");
  }
}
