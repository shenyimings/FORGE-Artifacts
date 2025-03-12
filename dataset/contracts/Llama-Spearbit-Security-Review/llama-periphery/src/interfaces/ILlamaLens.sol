// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface ILlamaLens {
  struct PermissionData {
    address target;
    bytes4 selector;
    address strategy;
  }

  function LLAMA_CORE_LOGIC() external view returns (address);

  function LLAMA_FACTORY() external view returns (address);

  function LLAMA_POLICY_LOGIC() external view returns (address);

  function computeLlamaAccountAddress(address llamaAccountLogic, bytes memory accountConfig, address llamaCore)
    external
    pure
    returns (address);

  function computeLlamaCoreAddress(string memory name, address deployer) external view returns (address);

  function computeLlamaExecutorAddress(address llamaCore) external pure returns (address);

  function computeLlamaExecutorAddress(string memory name, address deployer) external view returns (address);

  function computeLlamaPolicyAddress(string memory name, address deployer) external view returns (address);

  function computeLlamaPolicyMetadataAddress(
    address llamaPolicyMetadataLogic,
    bytes memory metadataConfig,
    address llamaPolicy
  ) external pure returns (address);

  function computeLlamaStrategyAddress(address llamaStrategyLogic, bytes memory strategyConfig, address llamaCore)
    external
    pure
    returns (address);

  function computePermissionId(PermissionData memory permission) external pure returns (bytes32);
}
