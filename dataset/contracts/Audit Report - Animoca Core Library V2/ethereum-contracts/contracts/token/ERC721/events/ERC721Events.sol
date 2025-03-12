// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @notice Emitted when a token is transferred.
/// @param from The previous token owner.
/// @param to The new token owner.
/// @param tokenId The transferred token identifier.
event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

/// @notice Emitted when a single token approval is set.
/// @param owner The token owner.
/// @param approved The approved address.
/// @param tokenId The approved token identifier.
event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

/// @notice Emitted when an approval for all tokens is set or unset.
/// @param owner The tokens owner.
/// @param operator The approved address.
/// @param approved True when then approval is set, false when it is unset.
event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

