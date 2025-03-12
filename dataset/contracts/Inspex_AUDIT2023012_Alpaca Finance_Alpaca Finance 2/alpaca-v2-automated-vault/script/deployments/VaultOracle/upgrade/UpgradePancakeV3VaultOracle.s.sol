// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { PancakeV3VaultOracle } from "src/oracles/PancakeV3VaultOracle.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/proxy/transparent/ProxyAdmin.sol";

contract UpgradePancakeV3VaultOracleScript is BaseScript {
  function run() public {
    vm.startBroadcast(deployerPrivateKey);

    // Deploy implementation
    address oracleImplementation = address(new PancakeV3VaultOracle());

    // Upgrade proxy to new implementation
    ProxyAdmin(proxyAdmin).upgrade(ITransparentUpgradeableProxy(payable(pancakeV3VaultOracle)), oracleImplementation);

    vm.stopBroadcast();

    _writeJson(vm.toString(oracleImplementation), ".automatedVault.pancake-v3-vault.vaultOracle.implementation");
  }
}
