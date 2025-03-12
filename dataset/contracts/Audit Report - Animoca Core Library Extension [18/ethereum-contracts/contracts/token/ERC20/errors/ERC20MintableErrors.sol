// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @notice Thrown when the minting tokens to the zero address.
error ERC20MintToAddressZero();

/// @notice Thrown when the `values` array sum overflows on a batch mint operation.
error ERC20BatchMintValuesOverflow();

/// @notice Thrown when the minting tokens overflows the supply.
/// @param supply The current supply.
/// @param value The amount of tokens being minted.
error ERC20TotalSupplyOverflow(uint256 supply, uint256 value);
