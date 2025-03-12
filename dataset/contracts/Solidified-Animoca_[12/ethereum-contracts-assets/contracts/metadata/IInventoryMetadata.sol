// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

// /**
//  * @dev Interface for retrieving core metadata attributes encoded in an integer
//  * and based on a specific bits layout. A layout consists of a mapping of names
//  * to bits position inside a uint256. The position is characterised by a length
//  * and an index and must remain in the bounds of 256 bits. Positions of a layout
//  * may overlap.
//  * Note that these functions are expected to work for any integer provided and
//  * should not be expected to have knowledge of the existence of a token in a
//  * specific contract.
//  */
// interface IInventoryMetadata {
//     /**
//      * @dev Get the address of the inventory contracts which delegated
//      * core metadata implementation to this contract.
//      * MUST return a valid IERC1155Inventory implementer address.
//      */
//     function inventoryMetadataDelegator() external view returns (address);
// }
