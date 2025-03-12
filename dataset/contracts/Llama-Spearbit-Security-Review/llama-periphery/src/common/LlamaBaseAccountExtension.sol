// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @dev This account extension is a template for creating new account extensions, and should not be used directly.
abstract contract LlamaBaseAccountExtension {
  /// @dev Thrown if you try to CALL a function that has the `onlyDelegatecall` modifier.
  error OnlyDelegateCall();

  /// @dev Add this to your account extension's methods to ensure the account extension can only be used via
  /// delegatecall, and not a regular call.
  modifier onlyDelegateCall() {
    if (address(this) == SELF) revert OnlyDelegateCall();
    _;
  }

  /// @dev Address of the account extension contract. We save it off because during a delegatecall `address(this)`
  /// refers to the caller's address, not this account extension's address.
  address internal immutable SELF;

  constructor() {
    SELF = address(this);
  }
}
