// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "v2/contracts/interfaces/ISoulSocietySBT.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface ISoulSocietySBTMetadata is ISoulSocietySBT {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId_) external view returns (string memory);
}