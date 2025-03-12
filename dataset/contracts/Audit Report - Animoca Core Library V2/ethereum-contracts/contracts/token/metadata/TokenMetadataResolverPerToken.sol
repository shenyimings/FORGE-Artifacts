// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {InconsistentArrayLengths} from "./../../CommonErrors.sol";
import {ITokenMetadataResolver} from "./interfaces/ITokenMetadataResolver.sol";
import {AccessControlStorage} from "./../../access/libraries/AccessControlStorage.sol";

/// @title TokenMetadataResolverPerToken.
/// @notice Token Metadata Resolver which stores the metadata URI for each token.
/// @notice Only minters of the target token contract can set the token metadata URI for this target contract.
contract TokenMetadataResolverPerToken is ITokenMetadataResolver {
    using AccessControlStorage for address;

    bytes32 public constant MINTER_ROLE = "minter";

    mapping(address => mapping(uint256 => string)) public metadataURI;

    /// @notice Sets the metadata URI for a token on a contract.
    /// @dev Reverts with {NotTargetContractRoleHolder} if the sender is not a 'minter' of the token contract.
    /// @param tokenContract The token contract on which to set the token URI.
    /// @param tokenId The token identifier.
    /// @param tokenURI The token metadata URI.
    function setTokenURI(address tokenContract, uint256 tokenId, string calldata tokenURI) public virtual {
        tokenContract.enforceHasTargetContractRole(MINTER_ROLE, msg.sender);
        metadataURI[tokenContract][tokenId] = tokenURI;
    }

    /// @notice Sets the metadata URIs for a batch of tokens on a contract.
    /// @dev Reverts with {InconsistentArrayLengths} if the arrays are of inconsistent lengths.
    /// @dev Reverts with {NotTargetContractRoleHolder} if the sender is not a 'minter' of the token contract.
    /// @param tokenContract The token contract on which to set the token URI.
    /// @param tokenIds The token identifiers.
    /// @param tokenURIs The token metadata URIs.
    function batchSetTokenURI(address tokenContract, uint256[] calldata tokenIds, string[] calldata tokenURIs) public virtual {
        uint256 length = tokenIds.length;
        if (length != tokenURIs.length) {
            revert InconsistentArrayLengths();
        }
        tokenContract.enforceHasTargetContractRole(MINTER_ROLE, msg.sender);

        for (uint256 i; i < length; ++i) {
            metadataURI[tokenContract][tokenIds[i]] = tokenURIs[i];
        }
    }

    /// @notice Gets the token metadata URI for a token.
    /// @param tokenContract The token contract for which to retrieve the token URI.
    /// @param tokenId The token identifier.
    /// @return tokenURI The token metadata URI.
    function tokenMetadataURI(address tokenContract, uint256 tokenId) external view virtual override returns (string memory tokenURI) {
        return metadataURI[tokenContract][tokenId];
    }
}
