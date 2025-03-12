// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployAutomatedVaultManagerScript is BaseScript {
  function run() public {
    address _vaultTokenImplementation = automatedVaultERC20Implementation;
    address _managementFeeTreasury = 0x2DD872C6f7275DAD633d7Deb1083EDA561E9B96b;
    address _withdrawTreasury = 0x2DD872C6f7275DAD633d7Deb1083EDA561E9B96b;

    vm.startBroadcast(deployerPrivateKey);

    // Deploy implementation
    address automatedVaultManagerImplementation = address(new AutomatedVaultManager());

    // Deploy proxy
    bytes memory initializerData = abi.encodeWithSelector(
      AutomatedVaultManager.initialize.selector, _vaultTokenImplementation, _managementFeeTreasury, _withdrawTreasury
    );
    address automatedVaultManagerProxy = address(
      new TransparentUpgradeableProxy(
      automatedVaultManagerImplementation,
      proxyAdmin,
      initializerData
      )
    );

    vm.stopBroadcast();

    _writeJson(vm.toString(automatedVaultManagerImplementation), ".automatedVault.automatedVaultManager.implementation");
    _writeJson(vm.toString(automatedVaultManagerProxy), ".automatedVault.automatedVaultManager.proxy");
  }
}
