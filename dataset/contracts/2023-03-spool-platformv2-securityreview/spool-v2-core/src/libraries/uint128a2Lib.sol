// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

type uint128a2 is uint256;

/**
 * @notice This library enables packing of sixteen uint16 elements into one uint256 word.
 */
library uint128a2Lib {
    /// @notice Number of bits per stored element.
    uint256 constant bits = 128;

    /// @notice Maximal number of elements stored.
    uint256 constant elements = 2;

    // must ensure that bits * elements <= 256

    /// @notice Range covered by stored element.
    uint256 constant range = 1 << bits;

    /// @notice Maximal value of stored element.
    uint256 constant max = range - 1;

    /**
     * @notice Gets element from packed array.
     * @param va Packed array.
     * @param index Index of element to get.
     * @return element Element of va stored in index index.
     */
    function get(uint128a2 va, uint256 index) internal pure returns (uint256) {
        require(index < elements);

        return (uint128a2.unwrap(va) >> (bits * index)) & max;
    }

    /**
     * @notice Sets element to packed array.
     * @param va Packed array.
     * @param index Index under which to store the element
     * @param ev Element to store.
     * @return va Packed array with stored element.
     */
    function set(uint128a2 va, uint256 index, uint256 ev) internal pure returns (uint128a2) {
        require(index < elements);
        require(ev < range);
        index *= bits;
        return uint128a2.wrap((uint128a2.unwrap(va) & ~(max << index)) | (ev << index));
    }
}
