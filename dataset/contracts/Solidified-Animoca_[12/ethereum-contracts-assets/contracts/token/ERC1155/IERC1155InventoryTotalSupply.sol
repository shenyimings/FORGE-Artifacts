// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

/**
 * @title ERC-1155 Multi Token Standard, optional InventoryTotalSupply extension
 * @dev See https://eips.ethereum.org/EIPS/eip-xxxx
 * Note: The ERC-165 identifier for this interface is 0xTODO.
 */
interface IERC1155InventoryTotalSupply {
    /**
     * Retrieves the total supply of `id`.
     * @param id The identifier for which to retrieve the supply of.
     * @return
     *  If `id` represents a collection (fungible token or non-fungible collection), the total supply for this collection.
     *  If `id` represents a non-fungible token, 1 if the token exists, else 0.
     */
    function totalSupply(uint256 id) external view returns (uint256);
}
