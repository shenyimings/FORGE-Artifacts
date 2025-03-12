// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Clones} from "@openzeppelin/proxy/Clones.sol";

import {ILlamaCore} from "src/interfaces/ILlamaCore.sol";
import {CasterConfig, LlamaTokenVotingConfig} from "src/lib/Structs.sol";
import {ILlamaTokenAdapter} from "src/token-voting/interfaces/ILlamaTokenAdapter.sol";
import {LlamaTokenGovernor} from "src/token-voting/LlamaTokenGovernor.sol";

/// @title LlamaTokenVotingFactory
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This contract enables Llama instances to deploy a token voting module.
contract LlamaTokenVotingFactory {
  // ========================
  // ======== Errors ========
  // ========================

  /// @dev Thrown when a token adapter has been incorrectly configured.
  error InvalidTokenAdapterConfig();

  // ========================
  // ======== Events ========
  // ========================

  /// @dev Emitted when a new Llama token voting module is created.
  event LlamaTokenVotingInstanceCreated(
    address indexed deployer,
    ILlamaCore indexed llamaCore,
    address indexed token,
    ILlamaTokenAdapter tokenAdapterLogic,
    ILlamaTokenAdapter tokenAdapter,
    uint256 nonce,
    LlamaTokenGovernor llamaTokenGovernor,
    uint256 chainId
  );

  // =================================================
  // ======== Constants and Storage Variables ========
  // =================================================

  /// @notice The Token Governor implementation (logic) contract.
  LlamaTokenGovernor public immutable LLAMA_TOKEN_GOVERNOR_LOGIC;

  /// @dev Set the logic contract used to deploy Token Voting modules.
  constructor(LlamaTokenGovernor llamaTokenGovernorLogic) {
    LLAMA_TOKEN_GOVERNOR_LOGIC = llamaTokenGovernorLogic;
  }

  /// @notice Deploys a new Llama token voting module.
  /// @param tokenVotingConfig The configuration of the new Llama token voting module.
  /// @return governor The address of the `LlamaTokenGovernor` (the deployed token voting module).
  function deploy(LlamaTokenVotingConfig memory tokenVotingConfig) external returns (LlamaTokenGovernor governor) {
    bytes32 salt = keccak256(
      abi.encodePacked(
        msg.sender, address(tokenVotingConfig.llamaCore), tokenVotingConfig.adapterConfig, tokenVotingConfig.nonce
      )
    );

    // Deploy and initialize token adapter based on provided logic address and config
    ILlamaTokenAdapter tokenAdapter =
      ILlamaTokenAdapter(Clones.cloneDeterministic(address(tokenVotingConfig.tokenAdapterLogic), salt));
    tokenAdapter.initialize(tokenVotingConfig.adapterConfig);

    // Check to see if token adapter was correctly initialized
    if (address(tokenAdapter.token()) == address(0)) revert InvalidTokenAdapterConfig();
    if (tokenAdapter.timestampToTimepoint(block.timestamp) == 0) revert InvalidTokenAdapterConfig();
    if (tokenAdapter.clock() == 0) revert InvalidTokenAdapterConfig();
    // Reverts if clock is inconsistent
    tokenAdapter.checkIfInconsistentClock();

    // Deploy and initialize `LlamaTokenGovernor` contract
    governor = LlamaTokenGovernor(Clones.cloneDeterministic(address(LLAMA_TOKEN_GOVERNOR_LOGIC), salt));
    governor.initialize(
      tokenVotingConfig.llamaCore, tokenAdapter, tokenVotingConfig.creationThreshold, tokenVotingConfig.casterConfig
    );

    emit LlamaTokenVotingInstanceCreated(
      msg.sender,
      tokenVotingConfig.llamaCore,
      tokenAdapter.token(),
      tokenVotingConfig.tokenAdapterLogic,
      tokenAdapter,
      tokenVotingConfig.nonce,
      governor,
      block.chainid
    );
  }
}
