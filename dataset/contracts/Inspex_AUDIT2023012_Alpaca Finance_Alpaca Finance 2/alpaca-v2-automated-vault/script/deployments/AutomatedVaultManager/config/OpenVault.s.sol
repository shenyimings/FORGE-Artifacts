// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract OpenVaultScript is BaseScript {
  function run() public {
    string memory _name = "Market Neutral USDT-BNB-500 PCS2";
    string memory _symbol = "N-USDT-BNB-500-PCS2";

    AutomatedVaultManager.OpenVaultParams memory params = AutomatedVaultManager.OpenVaultParams({
      worker: 0x4a0cb84D2DD2bc0Aa5CC256EF6Ec3A4e1b83E74c,
      vaultOracle: pancakeV3VaultOracle,
      executor: 0xd8BD07eDFd276AA23EB4B6806C904728B4C7DCb3,
      compressedMinimumDeposit: 100,
      compressedCapacity: type(uint32).max,
      managementFeePerSec: 0,
      withdrawalFeeBps: 0,
      toleranceBps: 9500,
      maxLeverage: 8
    });

    vm.startBroadcast(deployerPrivateKey);

    address _vaultToken = AutomatedVaultManager(automatedVaultManager).openVault(_name, _symbol, params);

    vm.stopBroadcast();

    console.log("newVaultToken : ", _vaultToken);
  }
}
