// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

// h/t Opensea
// Clever library for bitpacking an address + index + supply into a uint256 to represent the tokenId for an ERC1155

library TokenIdentifiers {
    uint8 private constant ADDRESS_BITS = 160;
    uint8 private constant INDEX_BITS = 56;
    uint8 private constant SUPPLY_BITS = 40;

    uint256 private constant SUPPLY_MASK = (uint256(1) << SUPPLY_BITS) - 1;
    uint256 private constant INDEX_MASK = ((uint256(1) << INDEX_BITS) - 1) ^ SUPPLY_MASK;

    function tokenMaxSupply(uint256 _id) internal pure returns (uint256) {
        return _id & SUPPLY_MASK;
    }

    // modified from original code to shift bits right to remove supply bits
    function tokenIndex(uint256 _id) internal pure returns (uint256) {
        return (_id & INDEX_MASK) >> SUPPLY_BITS;
    }

    function tokenCreator(uint256 _id) internal pure returns (address) {
        return address(uint160(_id >> (INDEX_BITS + SUPPLY_BITS)));
    }
}
