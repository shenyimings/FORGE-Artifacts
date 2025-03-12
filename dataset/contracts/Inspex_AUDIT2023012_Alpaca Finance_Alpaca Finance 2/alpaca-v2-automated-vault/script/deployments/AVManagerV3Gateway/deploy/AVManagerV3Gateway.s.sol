// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";
import { AVManagerV3Gateway } from "src/gateway/AVManagerV3Gateway.sol";

contract DeployAVManagerV3GatewayScript is BaseScript {
  function run() public {
    vm.startBroadcast(deployerPrivateKey);

    address _avManagerV3Gateway = address(new AVManagerV3Gateway(automatedVaultManager, wbnb));

    vm.stopBroadcast();

    _writeJson(vm.toString(_avManagerV3Gateway), ".automatedVault.avManagerV3Gateway");
  }
}
