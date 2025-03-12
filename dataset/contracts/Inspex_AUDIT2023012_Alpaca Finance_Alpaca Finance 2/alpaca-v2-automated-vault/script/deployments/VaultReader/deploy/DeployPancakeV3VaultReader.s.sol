// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";
import { PancakeV3VaultReader } from "src/reader/PancakeV3VaultReader.sol";

contract DeployPancakeV3VaultReaderScript is BaseScript {
  function run() public {
    vm.startBroadcast(deployerPrivateKey);

    address _vaultReader = address(new PancakeV3VaultReader(automatedVaultManager, bank, pancakeV3VaultOracle));

    vm.stopBroadcast();

    _writeJson(vm.toString(_vaultReader), ".automatedVault.pancake-v3-vault.pancakeV3VaultReader");
  }
}
