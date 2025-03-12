// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IERC721Metadata} from "./../interfaces/IERC721Metadata.sol";
import {ERC721Storage} from "./../libraries/ERC721Storage.sol";
import {TokenMetadataStorage} from "./../../metadata/libraries/TokenMetadataStorage.sol";
import {TokenMetadataBase} from "./../../metadata/base/TokenMetadataBase.sol";

/// @title ERC721 Non-Fungible Token Standard, optional extension: Metadata (proxiable version).
/// @notice This contracts uses an external resolver for managing individual tokens metadata.
/// @dev This contract is to be used via inheritance in a proxied implementation.
/// @dev Note: This contract requires ERC721 (Non-Fungible Token Standard).
abstract contract ERC721MetadataBase is TokenMetadataBase, IERC721Metadata {
    using ERC721Storage for ERC721Storage.Layout;
    using TokenMetadataStorage for TokenMetadataStorage.Layout;

    /// @inheritdoc IERC721Metadata
    function name() public view virtual override(IERC721Metadata, TokenMetadataBase) returns (string memory tokenName) {
        return TokenMetadataBase.name();
    }

    /// @inheritdoc IERC721Metadata
    function symbol() public view virtual override(IERC721Metadata, TokenMetadataBase) returns (string memory tokenSymbol) {
        return TokenMetadataBase.symbol();
    }

    /// @inheritdoc IERC721Metadata
    function tokenURI(uint256 tokenId) external view virtual returns (string memory uri) {
        ERC721Storage.layout().ownerOf(tokenId); // reverts if the token does not exist
        return TokenMetadataStorage.layout().tokenMetadataURI(address(this), tokenId);
    }
}
