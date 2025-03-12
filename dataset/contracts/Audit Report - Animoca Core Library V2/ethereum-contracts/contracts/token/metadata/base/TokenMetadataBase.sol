// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ITokenMetadataResolver} from "./../interfaces/ITokenMetadataResolver.sol";
import {TokenMetadataStorage} from "./../libraries/TokenMetadataStorage.sol";

/// @title TokenMetadataBase (proxiable version).
/// @notice Provides metadata management for token contracts (ERC721/ERC1155) which uses an external resolver for managing individual tokens metadata.
/// @dev This contract is to be used via inheritance in a proxied implementation.
abstract contract TokenMetadataBase {
    using TokenMetadataStorage for TokenMetadataStorage.Layout;

    /// @notice Gets the token name. E.g. "My Token".
    /// @return tokenName The token name.
    function name() public view virtual returns (string memory tokenName) {
        return TokenMetadataStorage.layout().name();
    }

    /// @notice Gets the token symbol. E.g. "TOK".
    /// @return tokenSymbol The token symbol.
    function symbol() public view virtual returns (string memory tokenSymbol) {
        return TokenMetadataStorage.layout().symbol();
    }

    /// @notice Gets the token metadata resolver address.
    /// @return tokenMetadataResolver The token metadata resolver address.
    function metadataResolver() external view virtual returns (ITokenMetadataResolver tokenMetadataResolver) {
        return TokenMetadataStorage.layout().metadataResolver();
    }
}
