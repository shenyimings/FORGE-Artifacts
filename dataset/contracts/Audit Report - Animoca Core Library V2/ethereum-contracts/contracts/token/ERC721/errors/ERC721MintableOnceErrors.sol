// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @notice Thrown when minting a token which has been burnt before (MintableOnce implementation).
/// @param tokenId The identifier of the token that has been burnt before.
error ERC721BurntToken(uint256 tokenId);
