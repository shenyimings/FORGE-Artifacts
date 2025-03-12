// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @notice Thrown when the allowance increase creates an overflow.
/// @param owner The owner of the tokens.
/// @param spender The spender of the tokens.
/// @param allowance The current allowance.
/// @param increment The allowance increase.
error ERC20AllowanceOverflow(address owner, address spender, uint256 allowance, uint256 increment);
