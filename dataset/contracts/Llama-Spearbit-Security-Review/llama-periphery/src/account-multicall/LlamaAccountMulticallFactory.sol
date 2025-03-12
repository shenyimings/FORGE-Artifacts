// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {LlamaAccountMulticallExtension} from "src/account-multicall/LlamaAccountMulticallExtension.sol";
import {LlamaAccountMulticallGuard} from "src/account-multicall/LlamaAccountMulticallGuard.sol";
import {LlamaAccountMulticallStorage} from "src/account-multicall/LlamaAccountMulticallStorage.sol";

/// @title LlamaAccountMulticallFactory
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This contract enables Llama instances to deploy an account multicall module.
contract LlamaAccountMulticallFactory {
  /// @dev Configuration of new Llama account multicall module.
  struct LlamaAccountMulticallConfig {
    address llamaExecutor; // The address of the Llama executor.
    uint256 nonce; // The nonce of the new account multicall module.
    LlamaAccountMulticallStorage.TargetSelectorAuthorization[] data; // The target-selectors to authorize.
  }

  /// @dev Emitted when a new Llama account multicall module is created.
  event LlamaAccountMulticallModuleCreated(
    address indexed deployer,
    address indexed llamaExecutor,
    uint256 nonce,
    address accountMulticallGuard,
    address accountMulticallExtension,
    address accountMulticallStorage,
    uint256 chainId
  );

  /// @notice Deploys a new Llama account multicall module.
  /// @param accountMulticallConfig The configuration of the new Llama account multicall module.
  /// @return accountMulticallGuard The deployed account multicall guard.
  /// @return accountMulticallExtension The deployed account multicall extension.
  /// @return accountMulticallStorage The deployed account multicall storage.
  function deploy(LlamaAccountMulticallConfig memory accountMulticallConfig)
    external
    returns (
      LlamaAccountMulticallGuard accountMulticallGuard,
      LlamaAccountMulticallExtension accountMulticallExtension,
      LlamaAccountMulticallStorage accountMulticallStorage
    )
  {
    bytes32 salt =
      keccak256(abi.encodePacked(msg.sender, accountMulticallConfig.llamaExecutor, accountMulticallConfig.nonce));

    // Deploy and initialize account multicall storage.
    accountMulticallStorage = new LlamaAccountMulticallStorage{salt: salt}(accountMulticallConfig.llamaExecutor);
    accountMulticallStorage.initializeAuthorizedTargetSelectors(accountMulticallConfig.data);

    // Deploy account multicall extension.
    accountMulticallExtension = new LlamaAccountMulticallExtension{salt: salt}(accountMulticallStorage);

    // Deploy account multicall guard.
    accountMulticallGuard = new LlamaAccountMulticallGuard{salt: salt}(accountMulticallExtension);

    emit LlamaAccountMulticallModuleCreated(
      msg.sender,
      accountMulticallConfig.llamaExecutor,
      accountMulticallConfig.nonce,
      address(accountMulticallGuard),
      address(accountMulticallExtension),
      address(accountMulticallStorage),
      block.chainid
    );
  }
}
