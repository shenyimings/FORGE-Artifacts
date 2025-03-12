// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IERC1155MetadataSetter} from "./../ERC1155/interfaces/IERC1155MetadataSetter.sol";
import {TokenMetadataResolverPerToken} from "./TokenMetadataResolverPerToken.sol";

/// @title TokenMetadataResolverPerTokenERC1155.
/// @notice Token Metadata Resolver which stores the metadata URI for each token, for ERC1155 token contracts.
/// @notice When a metadata URI is set, the target ERC1155 contract will be asked to emit a URI event.
/// @notice Only minters of the target token contract can set the token metadata URI for this target contract.
contract TokenMetadataResolverPerTokenERC1155 is TokenMetadataResolverPerToken {
    /// @inheritdoc TokenMetadataResolverPerToken
    /// @dev The token contract emits a {URI} event.
    function setTokenURI(address tokenContract, uint256 tokenId, string calldata tokenURI) public override {
        super.setTokenURI(tokenContract, tokenId, tokenURI);
        IERC1155MetadataSetter(tokenContract).setTokenURI(tokenId, tokenURI);
    }

    /// @inheritdoc TokenMetadataResolverPerToken
    /// @dev The token contract emits a {URI} event for each token.
    function batchSetTokenURI(address tokenContract, uint256[] calldata tokenIds, string[] calldata tokenURIs) public override {
        super.batchSetTokenURI(tokenContract, tokenIds, tokenURIs);
        IERC1155MetadataSetter(tokenContract).batchSetTokenURI(tokenIds, tokenURIs);
    }
}
