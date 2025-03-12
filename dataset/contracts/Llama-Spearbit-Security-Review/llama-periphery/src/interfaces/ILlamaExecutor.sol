// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title ILlamaExecutor
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This is the interface for LlamaExecutor.
interface ILlamaExecutor {
  function LLAMA_CORE() external view returns (address);
  function execute(address target, bool isScript, bytes calldata data)
    external
    payable
    returns (bool success, bytes memory result);
}
