// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { ProxyAdmin } from "@openzeppelin/proxy/transparent/ProxyAdmin.sol";

contract DeployProxyAdminScript is BaseScript {
  function run() public {
    vm.startBroadcast(deployerPrivateKey);

    address _proxyAdmin = address(new ProxyAdmin());

    vm.stopBroadcast();

    _writeJson(vm.toString(_proxyAdmin), ".proxyAdmin");
  }
}
