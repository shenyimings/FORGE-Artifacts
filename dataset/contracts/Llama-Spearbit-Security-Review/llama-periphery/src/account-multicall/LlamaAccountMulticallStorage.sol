// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {LlamaUtils} from "src/lib/LlamaUtils.sol";

/// @title Llama Account Multicall Storage
/// @author Llama (devsdosomething@llama.xyz)
/// @notice The storage contract for the `LlamaAccountMulticallExtension` contract.
/// @dev This is a separate storage contract to prevent storage collisions with the Llama account.
contract LlamaAccountMulticallStorage {
  // =========================
  // ======== Structs ========
  // =========================

  /// @dev Struct to hold authorized target-selectors.
  struct TargetSelectorAuthorization {
    address target; // The target contract.
    bytes4 selector; // The selector of the function being called.
    bool isAuthorized; // Is the target-selector authorized.
  }

  // ========================
  // ======== Errors ========
  // ========================

  /// @dev Thrown if `initializeAuthorizedTargetSelectors` is called again.
  error AlreadyInitialized();

  /// @dev Only callable by a Llama instance's executor.
  error OnlyLlama();

  // ========================
  // ======== Events ========
  // ========================

  /// @notice Emitted when a target-selector is authorized.
  event TargetSelectorAuthorized(address indexed target, bytes4 indexed selector, bool isAuthorized);

  // ===================================
  // ======== Storage Variables ========
  // ===================================

  /// @notice The Llama instance's executor.
  address public immutable LLAMA_EXECUTOR;

  /// @dev Whether the contract is initialized.
  bool internal initialized;

  /// @notice Mapping of all authorized target-selectors.
  mapping(address target => mapping(bytes4 selector => bool isAuthorized)) public authorizedTargetSelectors;

  // ======================================================
  // ======== Contract Creation and Initialization ========
  // ======================================================

  /// @dev Sets the Llama executor.
  constructor(address llamaExecutor) {
    LLAMA_EXECUTOR = llamaExecutor;
  }

  /// @notice Initializes the authorized target-selectors.
  /// @dev This function can only be called once. It should be called as part of the contract deployment.
  /// @param data The target-selectors to authorize.
  function initializeAuthorizedTargetSelectors(TargetSelectorAuthorization[] memory data) external {
    if (initialized) revert AlreadyInitialized();
    initialized = true;
    _setAuthorizedTargetSelectors(data);
  }

  // ================================
  // ======== External Logic ========
  // ================================

  /// @notice Sets the authorized target-selectors.
  /// @param data The target-selectors to authorize.
  function setAuthorizedTargetSelectors(TargetSelectorAuthorization[] memory data) external {
    if (msg.sender != LLAMA_EXECUTOR) revert OnlyLlama();
    _setAuthorizedTargetSelectors(data);
  }

  // ================================
  // ======== Internal Logic ========
  // ================================

  /// @dev Sets the authorized target-selectors.
  function _setAuthorizedTargetSelectors(TargetSelectorAuthorization[] memory data) internal {
    uint256 length = data.length;
    for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {
      authorizedTargetSelectors[data[i].target][data[i].selector] = data[i].isAuthorized;
      emit TargetSelectorAuthorized(data[i].target, data[i].selector, data[i].isAuthorized);
    }
  }
}
