// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @title ITokenMetadataResolver
/// @notice Interface for Token Metadata Resolvers.
interface ITokenMetadataResolver {
    /// @notice Gets the token metadata URI for a token.
    /// @param tokenContract The token contract for which to retrieve the token URI.
    /// @param tokenId The token identifier.
    /// @return tokenURI The token metadata URI.
    function tokenMetadataURI(address tokenContract, uint256 tokenId) external view returns (string memory tokenURI);
}
