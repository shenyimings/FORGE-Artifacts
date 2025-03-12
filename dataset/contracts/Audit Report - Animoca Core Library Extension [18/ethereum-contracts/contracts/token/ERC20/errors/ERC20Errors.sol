// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @notice Thrown when setting an allowance to the the zero address.
/// @param owner The owner of the tokens.
error ERC20ApprovalToAddressZero(address owner);

/// @notice Thrown when the allowance decreases below the current alowance set.
/// @param owner The owner of the tokens.
/// @param spender The spender of the tokens.
/// @param allowance The current allowance.
/// @param decrement The allowance decrease.
error ERC20InsufficientAllowance(address owner, address spender, uint256 allowance, uint256 decrement);

/// @notice Thrown when transferring tokens to the zero address.
/// @param owner The account from which the tokens are transferred.
error ERC20TransferToAddressZero(address owner);

/// @notice Thrown when transferring an amount of tokens greater than the current balance.
/// @param owner The owner of the tokens.
/// @param balance The current balance.
/// @param value The amount of tokens being transferred.
error ERC20InsufficientBalance(address owner, uint256 balance, uint256 value);
