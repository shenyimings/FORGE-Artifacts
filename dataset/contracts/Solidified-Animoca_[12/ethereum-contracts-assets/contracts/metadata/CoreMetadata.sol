// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

// import "@animoca/ethereum-contracts-core-1.1.1/contracts/introspection/IERC165.sol";
// import "@animoca/ethereum-contracts-core-1.1.1/contracts/utils/types/UInt256Extract.sol";
// import "@animoca/ethereum-contracts-core-1.1.1/contracts/algo/EnumMap.sol";
// import "./ICoreMetadata.sol";

// abstract contract CoreMetadata is IERC165, ICoreMetadata {
//     using UInt256Extract for uint256;
//     using EnumMap for EnumMap.Map;

//     /**
//      * A layout is a mapping from a bytes32 name to a uint256 position.
//      * A position informs on which bits to extract from an id to retrieve
//      * a specific metadata attribute. A uint256 position is composed as follow:
//      * - an index which represents the bit position where the attribute begins,
//      *   (encoded on the 128 most significant bits)
//      * - a length which represents the number of bits for the attribute.
//      *   (encoded on the 128 least significant bits)
//      *
//      * Shorthands:
//      * - layout = mapping(name => position)
//      * - position = index << 128 | length
//      * - attribute_mask = (1 << length) - 1) << index
//      * - attribute = id & attribute_mask
//      */
//     EnumMap.Map internal _bitsLayout;

//     constructor() internal {
//         // _registerInterface(type(ICoreMetadata).interfaceId);
//     }

//     function getAttribute(uint256 integer, bytes32 name) public view virtual override returns (uint256 value) {
//         uint256 position = uint256(_bitsLayout.get(name));
//         value = integer.extract(uint128(position), uint128(position >> 128));
//     }

//     function getAttributes(uint256 integer, bytes32[] memory names) public view virtual override returns (uint256[] memory values) {
//         values = new uint256[](names.length);
//         for (uint256 i = 0; i != names.length; ++i) {
//             uint256 position = uint256(_bitsLayout.get(names[i]));
//             values[i] = integer.extract(uint128(position), uint128(position >> 128));
//         }
//     }

//     function getAllAttributes(uint256 integer) public view virtual override returns (bytes32[] memory names, uint256[] memory values) {
//         uint256 length = _bitsLayout.length();
//         names = new bytes32[](length);
//         values = new uint256[](length);
//         for (uint256 i = 0; i != length; ++i) {
//             (bytes32 name, bytes32 pos) = _bitsLayout.at(i);
//             uint256 position = uint256(pos);
//             names[i] = name;
//             values[i] = integer.extract(uint128(position), uint128(position >> 128));
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

//     function _getLayout()
//         internal
//         view
//         virtual
//         returns (
//             bytes32[] memory names,
//             uint256[] memory lengths,
//             uint256[] memory indices
//         )
//     {
//         uint256 length = _bitsLayout.length();
//         names = new bytes32[](length);
//         lengths = new uint256[](length);
//         indices = new uint256[](length);
//         for (uint256 i = 0; i != length; ++i) {
//             (bytes32 name, bytes32 positionBytes) = _bitsLayout.at(i);
//             uint256 position = uint256(positionBytes);

//             names[i] = name;
//             lengths[i] = uint128(position);
//             indices[i] = uint128(position >> 128);
//         }
//     }

//     function _setLayout(
//         bytes32[] memory names,
//         uint256[] memory lengths,
//         uint256[] memory indices
//     ) internal virtual {
//         uint256 size = names.length;
//         require((lengths.length == size) && (indices.length == size), "CoreMeta: inconsistent arrays");
//         _clearLayout();
//         for (uint256 i = 0; i != size; ++i) {
//             _setAttribute(_bitsLayout, names[i], lengths[i], indices[i]);
//         }
//     }

//     function _clearLayout() internal virtual {
//         uint256 length = _bitsLayout.length();
//         for (uint256 i = 0; i != length; ++i) {
//             (bytes32 key, ) = _bitsLayout.at(0);
//             _bitsLayout.remove(key);
//         }
//     }
// }
