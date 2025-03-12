// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @notice Thrown when the permit is from the zero address.
error ERC20PermitFromAddressZero();

/// @notice Thrown when the permit is expired.
/// @param deadline The permit deadline.
error ERC20PermitExpired(uint256 deadline);

/// @notice Thrown when the permit signature cannot be verified.
error ERC20PermitInvalidSignature();
