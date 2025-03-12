// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @notice Emitted when some token is transferred.
/// @param operator The initiator of the transfer.
/// @param from The previous token owner.
/// @param to The new token owner.
/// @param id The transferred token identifier.
/// @param value The amount of token.
event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

/// @notice Emitted when a batch of tokens is transferred.
/// @param operator The initiator of the transfer.
/// @param from The previous tokens owner.
/// @param to The new tokens owner.
/// @param ids The transferred tokens identifiers.
/// @param values The amounts of tokens.
event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);

/// @notice Emitted when an approval for all tokens is set or unset.
/// @param owner The tokens owner.
/// @param operator The approved address.
/// @param approved True when then approval is set, false when it is unset.
event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

/// @notice Emitted when a token metadata URI is set updated.
/// @param value The token metadata URI.
/// @param id The token identifier.
event URI(string value, uint256 indexed id);
