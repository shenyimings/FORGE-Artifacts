// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

// import "@animoca/ethereum-contracts-core-1.1.1/contracts/introspection/IERC165.sol";
// import "@animoca/ethereum-contracts-core-1.1.1/contracts/utils/types/UInt256Extract.sol";
// import "@animoca/ethereum-contracts-core-1.1.1/contracts/algo/EnumMap.sol";
// import "./../token/ERC1155/IERC1155Inventory.sol";
// import "./ICoreMetadata.sol";
// import "./IInventoryMetadata.sol";

// abstract contract InventoryMetadata is IInventoryMetadata, ICoreMetadata, IERC165 {
//     using UInt256Extract for uint256;
//     using EnumMap for EnumMap.Map;

//     address public override inventoryMetadataDelegator;

//     /**
//      * @dev A layout is a mapping from a bytes32 name to a uint256 position.
//      * A position informs on which bits to extract from an id to retrieve
//      * a specific metadata attribute. A uint256 position is composed as follow:
//      * - a length which represents the number of bits for the attribute.
//      *   (encoded on the 128 least significant bits)
//      * - an index which represents the bit position where the attribute begins,
//      *   (encoded on the 128 most significant bits)
//      *
//      * Shorthands:
//      * - layout = mapping(name => position)
//      * - position = index << 128 | length
//      * - attribute_mask = (1 << length) - 1) << index
//      * - attribute = id & attribute_mask
//      */
//     EnumMap.Map internal _defaultFungibleLayout;
//     EnumMap.Map internal _defaultNonFungibleLayout;
//     mapping(uint256 => EnumMap.Map) internal _layouts;

//     constructor(uint256 nfCollectionMaskLength, address delegator) {
//         // TODO supportInterface
//         // _registerInterface(type(ICoreMetadata).interfaceId);
//         // _registerInterface(type(IInventoryMetadata).interfaceId);

//         _setInventoryMetadataDelegator(delegator);

//         /*
//          * Default Fungible Layout
//          *
//          *   256                                                                                     0
//          *    |--------------------------------------------------------------------------------------|
//          *                                     ^ baseCollectionId ^
//          */
//         _setAttribute(_defaultFungibleLayout, "baseCollectionId", 256, 0);

//         /*
//          * Default Non-Fungible Layout
//          *
//          *     < nfCollectionMaskLength >
//          *   256                                                                                      0
//          *    |-|-------------------------|-----------------------------------------------------------|
//          *     F   ^ baseCollectionId ^                        ^ baseTokenId ^
//          */
//         _setAttribute(_defaultNonFungibleLayout, "baseTokenId", 256 - nfCollectionMaskLength, 0);
//         _setAttribute(_defaultNonFungibleLayout, "baseCollectionId", nfCollectionMaskLength - 1, 256 - nfCollectionMaskLength);
//     }

//     function _setInventoryMetadataDelegator(address delegator) internal {
//         require(IERC165(delegator).supportsInterface(type(IERC1155Inventory).interfaceId), "InvMeta: invalid delegator");
//         inventoryMetadataDelegator = delegator;
//     }

//     /**
//      * @dev Retrieves an attribute which can be either in the default fungible/non-fungible
//      * layout or in the relevant collection layout.
//      */
//     function getAttribute(uint256 id, bytes32 name) public view virtual override returns (uint256) {
//         IERC1155Inventory delegator = IERC1155Inventory(inventoryMetadataDelegator);

//         EnumMap.Map storage layout = delegator.isFungible(id) ? _defaultFungibleLayout : _defaultNonFungibleLayout;

//         if (!layout.contains(name)) {
//             layout = _layouts[delegator.collectionOf(id)];
//         }
//         uint256 position = uint256(layout.get(name));

//         return id.extract(uint128(position), uint128(position >> 128));
//     }

//     function getAttributes(uint256 id, bytes32[] memory names) public view virtual override returns (uint256[] memory values) {
//         IERC1155Inventory delegator = IERC1155Inventory(inventoryMetadataDelegator);
//         EnumMap.Map storage layout = delegator.isFungible(id) ? _defaultFungibleLayout : _defaultNonFungibleLayout;

//         values = new uint256[](names.length);

//         for (uint256 i = 0; i != names.length; ++i) {
//             if (!layout.contains(names[i])) {
//                 layout = _layouts[delegator.collectionOf(id)];
//             }
//             uint256 position = uint256(layout.get(names[i]));

//             values[i] = id.extract(uint128(position), uint128(position >> 128));
//         }
//     }

//     /**
//      * @dev Retrieves attributes from both the default fungible/non-fungible
//      * layout and the relevant collection layout.
//      */
//     function getAllAttributes(uint256 id) public view virtual override returns (bytes32[] memory names, uint256[] memory values) {
//         IERC1155Inventory delegator = IERC1155Inventory(inventoryMetadataDelegator);

//         EnumMap.Map storage defaultLayout = delegator.isFungible(id) ? _defaultFungibleLayout : _defaultNonFungibleLayout;

//         EnumMap.Map storage collectionLayout = _layouts[delegator.collectionOf(id)];

//         uint256 defaultLayoutLength = defaultLayout.length();
//         uint256 collectionLayoutLength = collectionLayout.length();
//         uint256 length = defaultLayoutLength + collectionLayoutLength;

//         names = new bytes32[](length);
//         values = new uint256[](length);

//         bytes32 name;
//         bytes32 position;
//         uint256 index = 0;
//         for (uint256 i = 0; i != defaultLayoutLength; ++i) {
//             (name, position) = defaultLayout.at(i);
//             names[index] = name;
//             values[index] = id.extract(uint128(uint256(position)), uint128(uint256(position) >> 128));
//             ++index;
//         }

//         for (uint256 i = 0; i != collectionLayoutLength; ++i) {
//             (name, position) = collectionLayout.at(i);
//             names[index] = name;
//             values[index] = id.extract(uint128(uint256(position)), uint128(uint256(position) >> 128));
//             ++index;
//         }
//     }

//     function _setAttribute(
//         EnumMap.Map storage layout,
//         bytes32 name,
//         uint256 length,
//         uint256 index
//     ) internal {
//         // Ensures extraction preconditions are met
//         uint256(0).extract(length, index);

//         layout.set(name, bytes32(uint256((index << 128) | length)));
//     }

//     function _getLayout(uint256 collectionId)
//         internal
//         view
//         virtual
//         returns (
//             bytes32[] memory names,
//             uint256[] memory lengths,
//             uint256[] memory indices
//         )
//     {
//         EnumMap.Map storage layout = _layouts[collectionId];
//         // require(layout.length() != 0, "InventoryMetadata: get non-existent layout");
//         uint256 length = layout.length();
//         if (length != 0) {
//             names = new bytes32[](length);
//             lengths = new uint256[](length);
//             indices = new uint256[](length);
//             for (uint256 i = 0; i != length; ++i) {
//                 bytes32 name;
//                 bytes32 pos;
//                 (name, pos) = layout.at(i);
//                 uint256 position = uint256(pos);

//                 names[i] = name;
//                 lengths[i] = uint128(position);
//                 indices[i] = uint128(position >> 128);
//             }
//         }
//     }

//     function _setLayout(
//         uint256 collectionId,
//         bytes32[] memory names,
//         uint256[] memory lengths,
//         uint256[] memory indices
//     ) internal virtual {
//         uint256 size = names.length;
//         require((lengths.length == size) && (indices.length == size), "InvMeta: inconsistent arrays");
//         EnumMap.Map storage layout = _layouts[collectionId];
//         _clearLayout(layout);

//         IERC1155Inventory delegator = IERC1155Inventory(inventoryMetadataDelegator);
//         EnumMap.Map storage defaultLayout = delegator.isFungible(collectionId) ? _defaultFungibleLayout : _defaultNonFungibleLayout;

//         for (uint256 i = 0; i != size; ++i) {
//             bytes32 name = names[i];
//             require(!defaultLayout.contains(name), "InvMeta: override default attr");
//             _setAttribute(layout, name, lengths[i], indices[i]);
//         }
//     }

//     function _clearLayout(EnumMap.Map storage layout) internal {
//         uint256 length = layout.length();
//         for (uint256 i = 0; i != length; ++i) {
//             (bytes32 key, ) = layout.at(0);
//             layout.remove(key);
//         }
//     }

//     function _clearLayoutByCollectionId(uint256 collectionId) internal {
//         EnumMap.Map storage layout = _layouts[collectionId];
//         uint256 length = layout.length();
//         require(length != 0, "InvMeta: non-existing layout");
//         for (uint256 i = 0; i != length; ++i) {
//             (bytes32 key, ) = layout.at(0);
//             layout.remove(key);
//         }
//     }
// }
