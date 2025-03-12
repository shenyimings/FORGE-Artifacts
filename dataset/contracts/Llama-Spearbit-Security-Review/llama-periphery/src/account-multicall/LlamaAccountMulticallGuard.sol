// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {LlamaAccountMulticallExtension} from "src/account-multicall/LlamaAccountMulticallExtension.sol";
import {ILlamaActionGuard} from "src/interfaces/ILlamaActionGuard.sol";
import {ActionInfo} from "src/lib/Structs.sol";

/// @title Llama Account Multicall Guard
/// @author Llama (devsdosomething@llama.xyz)
/// @notice A guard that only allows the `LlamaAccountMulticallExtension.multicall` to be delegate-called
/// @dev This guard should be used to protect the `execute` function in the `LlamaAccount` contract
contract LlamaAccountMulticallGuard is ILlamaActionGuard {
  /// @dev Thrown if the call is not authorized.
  error UnauthorizedCall(address target, bytes4 selector, bool withDelegatecall);

  /// @notice The address of the Llama account multicall extension.
  LlamaAccountMulticallExtension public immutable ACCOUNT_MULTICALL_EXTENSION;

  /// @dev Initializes the Llama account multicall guard.
  constructor(LlamaAccountMulticallExtension accountMulticallExtension) {
    ACCOUNT_MULTICALL_EXTENSION = accountMulticallExtension;
  }

  /// @inheritdoc ILlamaActionGuard
  function validateActionCreation(ActionInfo calldata actionInfo) external view {
    // Decode the action calldata to get the LlamaAccount execute target, call type and call data.
    (address target, bool withDelegatecall,, bytes memory data) =
      abi.decode(actionInfo.data[4:], (address, bool, uint256, bytes));
    bytes4 selector = bytes4(data);

    // Check if the target is the Llama account multicall extension, selector is `multicall` and the call type is a
    // delegatecall.
    if (
      target != address(ACCOUNT_MULTICALL_EXTENSION) || selector != LlamaAccountMulticallExtension.multicall.selector
        || !withDelegatecall
    ) revert UnauthorizedCall(target, selector, withDelegatecall);
  }

  /// @inheritdoc ILlamaActionGuard
  function validatePreActionExecution(ActionInfo calldata actionInfo) external pure {}

  /// @inheritdoc ILlamaActionGuard
  function validatePostActionExecution(ActionInfo calldata actionInfo) external pure {}
}
