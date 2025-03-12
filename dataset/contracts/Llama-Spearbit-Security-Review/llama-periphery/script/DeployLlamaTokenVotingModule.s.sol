// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, stdJson} from "forge-std/Script.sol";

import {DeployUtils} from "script/DeployUtils.sol";

import {ILlamaCore} from "src/interfaces/ILlamaCore.sol";
import {CasterConfig, LlamaTokenVotingConfig} from "src/lib/Structs.sol";
import {ILlamaTokenAdapter} from "src/token-voting/interfaces/ILlamaTokenAdapter.sol";
import {LlamaTokenGovernor} from "src/token-voting/LlamaTokenGovernor.sol";
import {LlamaTokenVotingFactory} from "src/token-voting/LlamaTokenVotingFactory.sol";
import {DeployUtils} from "script/DeployUtils.sol";

contract DeployLlamaTokenVotingModule is Script {
  using stdJson for string;

  function run(address deployer, string memory configFile) public {
    string memory jsonInput = DeployUtils.readScriptInput(configFile);

    LlamaTokenVotingFactory factory = LlamaTokenVotingFactory(jsonInput.readAddress(".factory"));

    DeployUtils.print(string.concat("Deploying Llama token voting module to chain:", vm.toString(block.chainid)));

    CasterConfig memory casterConfig = CasterConfig(
      abi.decode(jsonInput.parseRaw(".casterConfig.voteQuorumPct"), (uint16)),
      abi.decode(jsonInput.parseRaw(".casterConfig.vetoQuorumPct"), (uint16)),
      abi.decode(jsonInput.parseRaw(".casterConfig.delayPeriodPct"), (uint16)),
      abi.decode(jsonInput.parseRaw(".casterConfig.castingPeriodPct"), (uint16))
    );

    LlamaTokenVotingConfig memory config = LlamaTokenVotingConfig(
      ILlamaCore(jsonInput.readAddress(".llamaCore")),
      ILlamaTokenAdapter(jsonInput.readAddress(".tokenAdapterLogic")),
      DeployUtils.readTokenAdapter(jsonInput),
      abi.decode(jsonInput.parseRaw(".nonce"), (uint256)),
      abi.decode(jsonInput.parseRaw(".creationThreshold"), (uint256)),
      casterConfig
    );

    vm.broadcast(deployer);
    LlamaTokenGovernor governor = factory.deploy(config);

    DeployUtils.print("Successfully deployed a new Llama token voting module");
    DeployUtils.print(string.concat("  LlamaTokenGovernor:     ", vm.toString(address(governor))));
  }
}
