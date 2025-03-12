// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { AutomatedVaultERC20 } from "src/AutomatedVaultERC20.sol";

contract DeployAutomatedVaultERC20ImplementationScript is BaseScript {
  function run() public {
    vm.startBroadcast(deployerPrivateKey);

    address _automatedVaultERC20Implementation = address(new AutomatedVaultERC20());

    vm.stopBroadcast();

    _writeJson(vm.toString(_automatedVaultERC20Implementation), ".automatedVault.automatedVaultERC20Implementation");
  }
}
