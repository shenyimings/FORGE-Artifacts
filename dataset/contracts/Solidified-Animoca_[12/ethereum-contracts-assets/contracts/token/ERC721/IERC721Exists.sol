// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

/**
 * @title ERC721 Non-Fungible Token Standard, optional exists extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 * Note: The ERC-165 identifier for this interface is 0x4f558e79.
 */
interface IERC721Exists {
    /**
     * @dev Checks the existence of an Non-Fungible Token
     * @param tokenId the token identifier to check the existence of.
     * @return bool true if the token belongs to a non-zero address, false otherwise
     */
    function exists(uint256 tokenId) external view returns (bool);
}
