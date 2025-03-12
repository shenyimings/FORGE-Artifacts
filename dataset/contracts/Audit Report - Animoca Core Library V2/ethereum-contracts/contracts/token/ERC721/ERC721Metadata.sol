// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ITokenMetadataResolver} from "./../metadata/interfaces/ITokenMetadataResolver.sol";
import {TokenMetadataStorage} from "./../metadata/libraries/TokenMetadataStorage.sol";
import {ERC721Storage} from "./libraries/ERC721Storage.sol";
import {ERC721MetadataBase} from "./base/ERC721MetadataBase.sol";

/// @title ERC721 Non-Fungible Token Standard, optional extension: Metadata (immutable version).
/// @notice This contracts uses an external resolver for managing individual tokens metadata.
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC721Metadata is ERC721MetadataBase {
    using TokenMetadataStorage for TokenMetadataStorage.Layout;

    /// @notice Marks the following ERC165 interfaces as supported: ERC721Metadata.
    /// @param name The name of the token.
    /// @param symbol The symbol of the token.
    /// @param metadataResolver The address of the metadata resolver contract.
    constructor(string memory name, string memory symbol, ITokenMetadataResolver metadataResolver) {
        TokenMetadataStorage.layout().constructorInit(name, symbol, metadataResolver);
        ERC721Storage.initERC721Metadata();
    }
}
