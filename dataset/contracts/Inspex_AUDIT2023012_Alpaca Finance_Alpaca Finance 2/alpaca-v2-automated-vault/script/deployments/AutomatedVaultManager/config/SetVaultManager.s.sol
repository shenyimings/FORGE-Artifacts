// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract SetVaultManagerScript is BaseScript {
  function run() public {
    address _vaultToken = 0x5dc672d3528535a97173AeD4671ccd2E5f627e44;
    address _manager = 0x2DD872C6f7275DAD633d7Deb1083EDA561E9B96b;
    bool _isManagerOk = true;

    vm.startBroadcast(deployerPrivateKey);

    AutomatedVaultManager(automatedVaultManager).setVaultManager(_vaultToken, _manager, _isManagerOk);

    vm.stopBroadcast();
  }
}
