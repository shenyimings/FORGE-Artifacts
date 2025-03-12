// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title Llama Account Logic Interface
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This is the interface for Llama accounts which can be used to hold assets for a Llama instance.
interface ILlamaAccount {
  /// @dev External call failed.
  /// @param result Data returned by the called function.
  error FailedExecution(bytes result);

  // -------- For Inspection --------

  /// @notice Returns the address of the Llama instance's executor.
  function llamaExecutor() external view returns (address);

  // -------- At Account Creation --------

  /// @notice Initializes a new clone of the account.
  /// @dev This function is called by the `_deployAccounts` function in the `LlamaCore` contract. The `initializer`
  /// modifier ensures that this function can be invoked at most once.
  /// @param config The account configuration, encoded as bytes to support differing constructor arguments in
  /// different account logic contracts.
  /// @return This return statement must be hardcoded to `true` to ensure that initializing an EOA
  /// (like the zero address) will revert.
  function initialize(bytes memory config) external returns (bool);

  // -------- Generic Execution --------

  /// @notice Execute arbitrary calls from the Llama Account.
  /// @dev Be careful and intentional while assigning permissions to a policyholder that can create an action to call
  /// this function, especially while using the delegatecall functionality as it can lead to arbitrary code execution in
  /// the context of this Llama account.
  /// @param target The address of the contract to call.
  /// @param withDelegatecall Whether to use delegatecall or call.
  /// @param value The amount of ETH to send with the call, taken from the Llama Account.
  /// @param callData The calldata to pass to the contract.
  /// @return The result of the call.
  function execute(address target, bool withDelegatecall, uint256 value, bytes calldata callData)
    external
    returns (bytes memory);
}
