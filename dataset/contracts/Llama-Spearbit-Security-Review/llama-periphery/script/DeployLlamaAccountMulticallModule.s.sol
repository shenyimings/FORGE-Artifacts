// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, stdJson} from "forge-std/Script.sol";

import {DeployUtils} from "script/DeployUtils.sol";

import {LlamaAccountMulticallExtension} from "src/account-multicall/LlamaAccountMulticallExtension.sol";
import {LlamaAccountMulticallFactory} from "src/account-multicall/LlamaAccountMulticallFactory.sol";
import {LlamaAccountMulticallGuard} from "src/account-multicall/LlamaAccountMulticallGuard.sol";
import {LlamaAccountMulticallStorage} from "src/account-multicall/LlamaAccountMulticallStorage.sol";

contract DeployLlamaAccountMulticallModule is Script {
  using stdJson for string;

  struct TargetSelectorAuthorizationInputs {
    // Attributes need to be in alphabetical order so JSON decodes properly.
    string comment;
    bytes selector;
    address target;
  }

  // Account multicall contracts.
  LlamaAccountMulticallStorage accountMulticallStorage;
  LlamaAccountMulticallExtension accountMulticallExtension;
  LlamaAccountMulticallGuard accountMulticallGuard;

  function run(address deployer, string memory configFile) public {
    string memory jsonInput = DeployUtils.readScriptInput(configFile);

    LlamaAccountMulticallFactory factory = LlamaAccountMulticallFactory(jsonInput.readAddress(".factory"));

    DeployUtils.print(string.concat("Deploying Llama account multicall module to chain:", vm.toString(block.chainid)));

    address llamaExecutor = jsonInput.readAddress(".llamaExecutor");
    uint256 nonce = jsonInput.readUint(".nonce");
    LlamaAccountMulticallStorage.TargetSelectorAuthorization[] memory data = readTargetSelectorAuthorizations(jsonInput);
    LlamaAccountMulticallFactory.LlamaAccountMulticallConfig memory config =
      LlamaAccountMulticallFactory.LlamaAccountMulticallConfig(llamaExecutor, nonce, data);

    vm.broadcast(deployer);
    (accountMulticallGuard, accountMulticallExtension, accountMulticallStorage) = factory.deploy(config);

    DeployUtils.print("Successfully deployed a new Llama account multicall module");
    DeployUtils.print(string.concat("  LlamaAccountMulticallGuard:     ", vm.toString(address(accountMulticallGuard))));
    DeployUtils.print(
      string.concat("  LlamaAccountMulticallExtension: ", vm.toString(address(accountMulticallExtension)))
    );
    DeployUtils.print(
      string.concat("  LlamaAccountMulticallStorage:   ", vm.toString(address(accountMulticallStorage)))
    );
  }

  function readTargetSelectorAuthorizations(string memory jsonInput)
    internal
    pure
    returns (LlamaAccountMulticallStorage.TargetSelectorAuthorization[] memory)
  {
    bytes memory data = jsonInput.parseRaw(".initialTargetSelectorAuthorizations");

    TargetSelectorAuthorizationInputs[] memory rawConfigs = abi.decode(data, (TargetSelectorAuthorizationInputs[]));

    LlamaAccountMulticallStorage.TargetSelectorAuthorization[] memory configs =
      new LlamaAccountMulticallStorage.TargetSelectorAuthorization[](rawConfigs.length);

    for (uint256 i = 0; i < rawConfigs.length; i++) {
      configs[i].target = rawConfigs[i].target;
      configs[i].selector = bytes4(rawConfigs[i].selector);
      configs[i].isAuthorized = true;
    }

    return configs;
  }
}
