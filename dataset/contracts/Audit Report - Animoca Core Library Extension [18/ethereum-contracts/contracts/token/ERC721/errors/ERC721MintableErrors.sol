// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @notice Thrown when minting a token to the zero address.
error ERC721MintToAddressZero();

/// @notice Thrown when minting a token that already exists.
/// @param tokenId The identifier of the token that already exists.
error ERC721ExistingToken(uint256 tokenId);
