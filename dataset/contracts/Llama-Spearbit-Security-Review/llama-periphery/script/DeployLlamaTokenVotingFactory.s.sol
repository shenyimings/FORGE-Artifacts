// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";

import {DeployUtils} from "script/DeployUtils.sol";
import {LlamaTokenGovernor} from "src/token-voting/LlamaTokenGovernor.sol";
import {LlamaTokenVotingFactory} from "src/token-voting/LlamaTokenVotingFactory.sol";
import {LlamaTokenAdapterVotesTimestamp} from "src/token-voting/token-adapters/LlamaTokenAdapterVotesTimestamp.sol";

contract DeployLlamaTokenVotingFactory is Script {
  // Logic contracts.
  LlamaTokenGovernor llamaTokenGovernorLogic;
  LlamaTokenAdapterVotesTimestamp llamaTokenAdapterTimestampLogic;

  // Factory contracts.
  LlamaTokenVotingFactory tokenVotingFactory;

  function run() public {
    DeployUtils.print(
      string.concat("Deploying Llama token voting factory and logic contracts to chain:", vm.toString(block.chainid))
    );

    vm.broadcast();
    llamaTokenGovernorLogic = new LlamaTokenGovernor();
    DeployUtils.print(string.concat("  LlamaTokenGovernorLogic: ", vm.toString(address(llamaTokenGovernorLogic))));

    vm.broadcast();
    tokenVotingFactory = new LlamaTokenVotingFactory(llamaTokenGovernorLogic);
    DeployUtils.print(string.concat("  LlamaTokenVotingFactory: ", vm.toString(address(tokenVotingFactory))));

    vm.broadcast();
    llamaTokenAdapterTimestampLogic = new LlamaTokenAdapterVotesTimestamp();
    DeployUtils.print(
      string.concat("  LlamaTokenAdapterVotesTimestamp: ", vm.toString(address(llamaTokenAdapterTimestampLogic)))
    );
  }
}
