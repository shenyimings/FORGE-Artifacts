// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { PancakeV3VaultOracle } from "src/oracles/PancakeV3VaultOracle.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployPancakeV3VaultOracleScript is BaseScript {
  uint16 constant MAX_PRICE_AGE = 3_600;
  uint16 constant MAX_PRICE_DIFF = 10_500;

  function run() public {
    address _pancakeV3PositionManager = pancakeV3PositionManager;
    address _bank = bank;

    vm.startBroadcast(deployerPrivateKey);

    // Deploy implementation
    address oracleImplementation = address(new PancakeV3VaultOracle());

    // Deploy proxy
    bytes memory initializerData = abi.encodeWithSelector(
      PancakeV3VaultOracle.initialize.selector, _pancakeV3PositionManager, _bank, MAX_PRICE_AGE, MAX_PRICE_DIFF
    );
    address oracleProxy = address(
      new TransparentUpgradeableProxy(
      oracleImplementation,
      proxyAdmin,
      initializerData
      )
    );

    vm.stopBroadcast();

    _writeJson(vm.toString(oracleImplementation), ".automatedVault.pancake-v3-vault.vaultOracle.implementation");
    _writeJson(vm.toString(oracleProxy), ".automatedVault.pancake-v3-vault.vaultOracle.proxy");
  }
}
