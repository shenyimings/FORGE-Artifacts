// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {VmSafe} from "forge-std/Vm.sol";
import {console2, stdJson} from "forge-std/Script.sol";

import {LlamaTokenAdapterVotesTimestamp} from "src/token-voting/token-adapters/LlamaTokenAdapterVotesTimestamp.sol";

library DeployUtils {
  using stdJson for string;

  address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
  VmSafe internal constant VM = VmSafe(VM_ADDRESS);

  function readScriptInput(string memory filename) internal view returns (string memory) {
    string memory inputDir = string.concat(VM.projectRoot(), "/script/input/");
    string memory chainDir = string.concat(VM.toString(block.chainid), "/");
    return VM.readFile(string.concat(inputDir, chainDir, filename));
  }

  function print(string memory message) internal view {
    // Avoid getting flooded with logs during tests. Note that fork tests will show logs with this
    // approach, because there's currently no way to tell which environment we're in, e.g. script
    // or test. This is being tracked in https://github.com/foundry-rs/foundry/issues/2900.
    if (block.chainid != 31_337) console2.log(message);
  }

  function readTokenAdapter(string memory jsonInput) internal pure returns (bytes memory) {
    address tokenAddress = jsonInput.readAddress(".tokenAddress");
    return abi.encode(LlamaTokenAdapterVotesTimestamp.Config(tokenAddress));
  }
}
