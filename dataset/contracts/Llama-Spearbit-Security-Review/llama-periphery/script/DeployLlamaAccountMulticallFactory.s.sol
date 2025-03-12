// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, stdJson} from "forge-std/Script.sol";

import {DeployUtils} from "script/DeployUtils.sol";

import {LlamaAccountMulticallFactory} from "src/account-multicall/LlamaAccountMulticallFactory.sol";

contract DeployLlamaAccountMulticallFactory is Script {
  // Factory contracts.
  LlamaAccountMulticallFactory accountMulticallFactory;

  function run() public {
    DeployUtils.print(string.concat("Deploying Llama account multicall factory to chain:", vm.toString(block.chainid)));

    vm.broadcast();
    accountMulticallFactory = new LlamaAccountMulticallFactory();
    DeployUtils.print(string.concat("  LlamaAccountMulticallFactory: ", vm.toString(address(accountMulticallFactory))));
  }
}
