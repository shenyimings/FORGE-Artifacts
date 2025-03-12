// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ITokenMetadataResolver} from "./interfaces/ITokenMetadataResolver.sol";
import {ContractOwnershipStorage} from "./../../access/libraries/ContractOwnershipStorage.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title TokenMetadataResolverWithBaseURI.
/// @notice Token Metadata Resolver which uses a base metadata URI concatenated with the token identifier to produce a token metadata URI.
/// @notice Only the owner of the target token contract can set the base metadata URI for this target contract.
contract TokenMetadataResolverWithBaseURI is ITokenMetadataResolver {
    using ContractOwnershipStorage for address;
    using Strings for uint256;

    mapping(address => string) public baseMetadataURI;

    /// @notice Emitted when the base metadata URI is set.
    /// @param tokenContract The token contract on which the base metadata URI was set.
    /// @param baseMetadataURI The base metadata URI.
    event BaseMetadataURISet(address tokenContract, string baseMetadataURI);

    /// @notice Sets the base metadata URI.
    /// @dev Reverts with {NotTargetContractOwner} if the sender is not the owner of the token contract.
    /// @dev Emits a {BaseMetadataURISet} event.
    /// @param tokenContract The token contract on which to set the base metadata URI.
    /// @param baseURI The base metadata URI.
    function setBaseMetadataURI(address tokenContract, string calldata baseURI) external {
        tokenContract.enforceIsTargetContractOwner(msg.sender);
        baseMetadataURI[tokenContract] = baseURI;
        emit BaseMetadataURISet(tokenContract, baseURI);
    }

    /// @notice Gets the token metadata URI for a token as the concatenation of the base metadata URI and the token identifier.
    /// @param tokenContract The token contract for which to retrieve the token URI.
    /// @param tokenId The token identifier.
    /// @return tokenURI The token metadata URI as the concatenation of the base metadata URI and the token identifier.
    function tokenMetadataURI(address tokenContract, uint256 tokenId) external view returns (string memory tokenURI) {
        return string(abi.encodePacked(baseMetadataURI[tokenContract], tokenId.toString()));
    }
}
