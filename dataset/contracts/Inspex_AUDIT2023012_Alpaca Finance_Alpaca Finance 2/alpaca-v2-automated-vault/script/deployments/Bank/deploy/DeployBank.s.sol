// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { Bank } from "src/Bank.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployBankScript is BaseScript {
  function run() public {
    address _moneyMarket = moneyMarket;
    address _automatedVaultManager = automatedVaultManager;

    vm.startBroadcast(deployerPrivateKey);

    // Deploy implementation
    address bankImplementation = address(new Bank());

    // Deploy proxy
    bytes memory initializerData =
      abi.encodeWithSelector(Bank.initialize.selector, _moneyMarket, _automatedVaultManager);
    address bankProxy = address(
      new TransparentUpgradeableProxy(
      bankImplementation,
      proxyAdmin,
      initializerData
      )
    );

    vm.stopBroadcast();

    _writeJson(vm.toString(bankImplementation), ".automatedVault.bank.implementation");
    _writeJson(vm.toString(bankProxy), ".automatedVault.bank.proxy");
  }
}
