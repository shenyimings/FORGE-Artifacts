// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @notice Thrown when trying to approveForAll oneself.
/// @param account The account trying to approveForAll itself.
error ERC1155SelfApprovalForAll(address account);

/// @notice Thrown when transferring tokens to the zero address.
error ERC1155TransferToAddressZero();

/// @notice Thrown when a sender tries to transfer tokens but is neither the owner nor approved by the owner.
/// @param sender The sender.
/// @param owner The owner.
error ERC1155NonApproved(address sender, address owner);

/// @notice Thrown when transferring an amount of tokens greater than the current balance.
/// @param owner The owner.
/// @param id The token identifier.
/// @param balance The current balance.
/// @param value The amount of tokens to transfer.
error ERC1155InsufficientBalance(address owner, uint256 id, uint256 balance, uint256 value);

/// @notice Thrown when minting or transferring an amount of tokens that would overflow the recipient's balance.
/// @param recipient The recipient.
/// @param id The token identifier.
/// @param balance The current balance.
/// @param value The amount of tokens to transfer.
error ERC1155BalanceOverflow(address recipient, uint256 id, uint256 balance, uint256 value);

/// @notice Thrown when a safe transfer is rejected by the recipient contract.
/// @param recipient The recipient contract.
/// @param id The token identifier.
/// @param value The amount of tokens to transfer.
error ERC1155SafeTransferRejected(address recipient, uint256 id, uint256 value);

/// @notice Thrown when a safe batch transfer is rejected by the recipient contract.
/// @param recipient The recipient contract.
/// @param ids The token identifiers.
/// @param values The amounts of tokens to transfer.
error ERC1155SafeBatchTransferRejected(address recipient, uint256[] ids, uint256[] values);

/// @notice Thrown when querying the balance of the zero address.
error ERC1155BalanceOfAddressZero();
