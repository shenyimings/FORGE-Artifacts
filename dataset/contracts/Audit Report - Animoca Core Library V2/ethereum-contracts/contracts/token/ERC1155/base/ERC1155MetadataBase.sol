// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {InconsistentArrayLengths} from "./../../../CommonErrors.sol";
import {NotMetadataResolver} from "./../../metadata/errors/TokenMetadataErrors.sol";
import {URI} from "./../events/ERC1155Events.sol";
import {IERC1155MetadataURI} from "./../interfaces/IERC1155MetadataURI.sol";
import {IERC1155MetadataSetter} from "./../interfaces/IERC1155MetadataSetter.sol";
import {TokenMetadataStorage} from "./../../metadata/libraries/TokenMetadataStorage.sol";
import {TokenMetadataBase} from "./../../metadata/base/TokenMetadataBase.sol";

/// @title ERC1155 Multi Token Standard, optional extension: Metadata (proxiable version).
/// @notice This contracts uses an external resolver for managing individual tokens metadata.
/// @dev This contract is to be used via inheritance in a proxied implementation.
/// @dev Note: This contract requires ERC1155 (Multi Token Standard).
abstract contract ERC1155MetadataBase is TokenMetadataBase, IERC1155MetadataURI, IERC1155MetadataSetter {
    using TokenMetadataStorage for TokenMetadataStorage.Layout;

    /// @inheritdoc IERC1155MetadataURI
    function uri(uint256 tokenId) external view virtual returns (string memory metadataURI) {
        return TokenMetadataStorage.layout().tokenMetadataURI(address(this), tokenId);
    }

    /// @notice Emits the URI event when a token metadata URI is set by the metadata resolver.
    /// @dev Reverts if the caller is not the metadata resolver.
    /// @dev Emits a {URI} event.
    /// @param tokenId The token identifier.
    /// @param tokenURI The token metadata URI.
    function setTokenURI(uint256 tokenId, string calldata tokenURI) external virtual {
        if (msg.sender != address(TokenMetadataStorage.layout().metadataResolver())) revert NotMetadataResolver(msg.sender);
        emit URI(tokenURI, tokenId);
    }

    /// @notice Emits URI events when a batch of token metadata URIs is set by the metadata resolver.
    /// @dev Reverts if `tokenIds` and `tokenURIs` have different lengths.
    /// @dev Reverts if the caller is not the metadata resolver.
    /// @dev Emits a {URI} event for each token.
    /// @param tokenIds The token identifiers.
    /// @param tokenURIs The token metadata URIs.
    function batchSetTokenURI(uint256[] calldata tokenIds, string[] calldata tokenURIs) external virtual {
        if (tokenIds.length != tokenURIs.length) revert InconsistentArrayLengths();
        if (msg.sender != address(TokenMetadataStorage.layout().metadataResolver())) revert NotMetadataResolver(msg.sender);

        for (uint256 i; i < tokenIds.length; ++i) {
            emit URI(tokenURIs[i], tokenIds[i]);
        }
    }
}
