// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IERC1155MetadataSetter {
    /// @notice Sets the metadata URI for a token.
    /// @dev Emits a {URI} event.
    /// @param tokenId The token identifier.
    /// @param tokenURI The token metadata URI.
    function setTokenURI(uint256 tokenId, string calldata tokenURI) external;

    /// @notice Sets the metadata URIs for a batch of tokens.
    /// @dev Reverts with {InconsistentArrayLengths} if the arrays are of inconsistent lengths.
    /// @dev Emits a {URI} event for each token.
    /// @param tokenIds The token identifiers.
    /// @param tokenURIs The token metadata URIs.
    function batchSetTokenURI(uint256[] calldata tokenIds, string[] calldata tokenURIs) external;
}
