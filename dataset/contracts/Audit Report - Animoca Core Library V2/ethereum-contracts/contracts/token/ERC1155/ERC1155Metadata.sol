// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ITokenMetadataResolver} from "./../metadata/interfaces/ITokenMetadataResolver.sol";
import {TokenMetadataStorage} from "./../metadata/libraries/TokenMetadataStorage.sol";
import {ERC1155Storage} from "./libraries/ERC1155Storage.sol";
import {ERC1155MetadataBase} from "./base/ERC1155MetadataBase.sol";

/// @title ERC1155 Multi Token Standard, optional extension: Metadata (immutable version).
/// @notice This contracts uses an external resolver for managing individual tokens metadata.
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC1155Metadata is ERC1155MetadataBase {
    using TokenMetadataStorage for TokenMetadataStorage.Layout;

    /// @notice Marks the following ERC165 interfaces as supported: ERC1155MetadataURI.
    /// @param name The name of the token.
    /// @param symbol The symbol of the token.
    /// @param metadataResolver The address of the metadata resolver contract.
    constructor(string memory name, string memory symbol, ITokenMetadataResolver metadataResolver) {
        TokenMetadataStorage.layout().constructorInit(name, symbol, metadataResolver);
        ERC1155Storage.initERC1155MetadataURI();
    }
}
