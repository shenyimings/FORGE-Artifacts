// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ITokenMetadataResolver} from "./../interfaces/ITokenMetadataResolver.sol";
import {ProxyInitialization} from "./../../../proxy/libraries/ProxyInitialization.sol";

library TokenMetadataStorage {
    struct Layout {
        string tokenName;
        string tokenSymbol;
        ITokenMetadataResolver tokenMetadataResolver;
    }

    bytes32 internal constant LAYOUT_STORAGE_SLOT = bytes32(uint256(keccak256("animoca.token.metadata.TokenMetadata.storage")) - 1);
    bytes32 internal constant PROXY_INIT_PHASE_SLOT = bytes32(uint256(keccak256("animoca.token.metadata.TokenMetadata.phase")) - 1);

    /// @notice Initializes the metadata storage (immutable version).
    /// @dev Note: This function should be called ONLY in the constructor of an immutable (non-proxied) contract.
    /// @param tokenName The token name.
    /// @param tokenSymbol The token symbol.
    /// @param tokenMetadataResolver The address of the metadata resolver contract.
    function constructorInit(
        Layout storage s,
        string memory tokenName,
        string memory tokenSymbol,
        ITokenMetadataResolver tokenMetadataResolver
    ) internal {
        s.tokenName = tokenName;
        s.tokenSymbol = tokenSymbol;
        s.tokenMetadataResolver = tokenMetadataResolver;
    }

    /// @notice Initializes the metadata storage (proxied version).
    /// @notice Sets the proxy initialization phase to `1`.
    /// @dev Note: This function should be called ONLY in the init function of a proxied contract.
    /// @dev Reverts with {InitializationPhaseAlreadyReached} if the proxy initialization phase is set to `1` or above.
    /// @param tokenName The token name.
    /// @param tokenSymbol The token symbol.
    /// @param tokenMetadataResolver The address of the metadata resolver contract.
    function proxyInit(
        Layout storage s,
        string calldata tokenName,
        string calldata tokenSymbol,
        ITokenMetadataResolver tokenMetadataResolver
    ) internal {
        ProxyInitialization.setPhase(PROXY_INIT_PHASE_SLOT, 1);
        s.tokenName = tokenName;
        s.tokenSymbol = tokenSymbol;
        s.tokenMetadataResolver = tokenMetadataResolver;
    }

    /// @notice Gets the name of the token.
    /// @return tokenName The name of the token contract.
    function name(Layout storage s) internal view returns (string memory tokenName) {
        return s.tokenName;
    }

    /// @notice Gets the symbol of the token.
    /// @return tokenSymbol The symbol of the token contract.
    function symbol(Layout storage s) internal view returns (string memory tokenSymbol) {
        return s.tokenSymbol;
    }

    /// @notice Gets the address of the token metadata resolver.
    /// @return tokenMetadataResolver The address of the token metadata resolver.
    function metadataResolver(Layout storage s) internal view returns (ITokenMetadataResolver tokenMetadataResolver) {
        return s.tokenMetadataResolver;
    }

    /// @notice Gets the token metadata URI retieved from the metadata resolver contract.
    /// @param tokenContract The address of the token contract.
    /// @param tokenId The ID of the token.
    function tokenMetadataURI(Layout storage s, address tokenContract, uint256 tokenId) internal view returns (string memory) {
        return s.tokenMetadataResolver.tokenMetadataURI(tokenContract, tokenId);
    }

    function layout() internal pure returns (Layout storage s) {
        bytes32 position = LAYOUT_STORAGE_SLOT;
        assembly {
            s.slot := position
        }
    }
}
