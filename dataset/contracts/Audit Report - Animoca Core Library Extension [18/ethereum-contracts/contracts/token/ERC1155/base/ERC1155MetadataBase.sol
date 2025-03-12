// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IERC1155MetadataURI} from "./../interfaces/IERC1155MetadataURI.sol";
import {TokenMetadataStorage} from "./../../metadata/libraries/TokenMetadataStorage.sol";
import {TokenMetadataBase} from "./../../metadata/base/TokenMetadataBase.sol";

/// @title ERC1155 Multi Token Standard, optional extension: Metadata (proxiable version).
/// @notice This contracts uses an external resolver for managing individual tokens metadata.
/// @dev This contract is to be used via inheritance in a proxied implementation.
/// @dev Note: This contract requires ERC1155 (Multi Token Standard).
abstract contract ERC1155MetadataBase is TokenMetadataBase, IERC1155MetadataURI {
    using TokenMetadataStorage for TokenMetadataStorage.Layout;

    /// @inheritdoc IERC1155MetadataURI
    function uri(uint256 tokenId) external view virtual returns (string memory metadataURI) {
        return TokenMetadataStorage.layout().tokenMetadataURI(address(this), tokenId);
    }
}
