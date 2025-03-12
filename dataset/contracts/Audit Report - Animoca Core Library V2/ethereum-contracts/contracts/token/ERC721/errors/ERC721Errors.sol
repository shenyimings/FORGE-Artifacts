// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @notice Thrown when trying to approve oneself.
/// @param account The account trying to approve itself.
error ERC721SelfApproval(address account);

/// @notice Thrown when trying to approveForAll oneself.
/// @param account The account trying to approveForAll itself.
error ERC721SelfApprovalForAll(address account);

/// @notice Thrown when a sender tries to set a token approval but is neither the owner nor approvedForAll by the owner.
/// @param sender The message sender.
/// @param tokenId The identifier of the token.
error ERC721NonApprovedForApproval(address sender, address owner, uint256 tokenId);

/// @notice Thrown when transferring a token to the zero address.
error ERC721TransferToAddressZero();

/// @notice Thrown when a token does not exist but is required to.
/// @param tokenId The identifier of the token that was checked.
error ERC721NonExistingToken(uint256 tokenId);

/// @notice Thrown when a sender tries to transfer a token but is neither the owner nor approved by the owner.
/// @param sender The message sender.
/// @param tokenId The identifier of the token.
error ERC721NonApprovedForTransfer(address sender, address owner, uint256 tokenId);

/// @notice Thrown when a token is not owned by the expected account.
/// @param account The account that was expected to own the token.
/// @param tokenId The identifier of the token.
error ERC721NonOwnedToken(address account, uint256 tokenId);

/// @notice Thrown when a safe transfer is rejected by the recipient contract.
/// @param recipient The recipient contract.
/// @param tokenId The identifier of the token.
error ERC721SafeTransferRejected(address recipient, uint256 tokenId);

/// @notice Thrown when querying the balance of the zero address.
error ERC721BalanceOfAddressZero();
