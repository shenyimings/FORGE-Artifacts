// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @notice Thrown when setting a royalty percentage that is above 100% (> FEE_DENOMINATOR).
/// @param percentage The royalty percentage that was attempted to be set.
error ERC2981IncorrectRoyaltyPercentage(uint256 percentage);

/// @notice Thrown when setting a royalty receiver that is the zero address.
error ERC2981IncorrectRoyaltyReceiver();
