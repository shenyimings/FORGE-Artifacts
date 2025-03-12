// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to bits.
 */
library Bits {
    uint256 internal constant MASK_BIT_COUNT_ALL_3   = 0x3333333333333333333333333333333333333333333333333333333333333333;
    uint256 internal constant MASK_BIT_COUNT_ALL_5   = 0x5555555555555555555555555555555555555555555555555555555555555555;
    uint256 internal constant MASK_BIT_COUNT_LOW_4   = 0x0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F;
    uint256 internal constant MASK_BIT_COUNT_LOW_8   = 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF;
    uint256 internal constant MASK_BIT_COUNT_LOW_16  = 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF;
    uint256 internal constant MASK_BIT_COUNT_LOW_32  = 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF;
    uint256 internal constant MASK_BIT_COUNT_LOW_64  = 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF;
    uint256 internal constant MASK_BIT_COUNT_LOW_128 = 0x00000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    /**
     * @dev Returns the number of bits set to true in the given `value`.
     */
    function popCount(uint256 flags) internal pure returns (uint256) {
        if (flags == 0)
            return 0;

        assembly {
            //Add every 1 bits in parallel.
            //flags = (flags & MASK_BIT_COUNT_ALL_5) + ((flags >> 1) & MASK_BIT_COUNT_ALL_5);
            flags := add(and(flags, MASK_BIT_COUNT_ALL_5), and(shr(1, flags), MASK_BIT_COUNT_ALL_5))

            //Add every 2 bits in parallel.
            //flags = (flags & MASK_BIT_COUNT_ALL_3) + ((flags >> 2) & MASK_BIT_COUNT_ALL_3);
            flags := add(and(flags, MASK_BIT_COUNT_ALL_3), and(shr(2, flags), MASK_BIT_COUNT_ALL_3))

            //Add every 4 bits in parallel.
            //flags = (flags & MASK_BIT_COUNT_LOW_4) + ((flags >> 4) & MASK_BIT_COUNT_LOW_4);
            flags := add(and(flags, MASK_BIT_COUNT_LOW_4), and(shr(4, flags), MASK_BIT_COUNT_LOW_4))

            //Add every 8 bits in parallel.
            //flags = (flags & MASK_BIT_COUNT_LOW_8) + ((flags >> 8) & MASK_BIT_COUNT_LOW_8);
            flags := add(and(flags, MASK_BIT_COUNT_LOW_8), and(shr(8, flags), MASK_BIT_COUNT_LOW_8))

            //Add every 16 bits in parallel.
            //flags = (flags & MASK_BIT_COUNT_LOW_16) + ((flags >> 16) & MASK_BIT_COUNT_LOW_16);
            flags := add(and(flags, MASK_BIT_COUNT_LOW_16), and(shr(16, flags), MASK_BIT_COUNT_LOW_16))

            //Add every 32 bits in parallel.
            //flags = (flags & MASK_BIT_COUNT_LOW_32) + ((flags >> 32) & MASK_BIT_COUNT_LOW_32);
            flags := add(and(flags, MASK_BIT_COUNT_LOW_32), and(shr(32, flags), MASK_BIT_COUNT_LOW_32))

            //Add every 64 bits in parallel.
            //flags = (flags & MASK_BIT_COUNT_LOW_64) + ((flags >> 64) & MASK_BIT_COUNT_LOW_64);
            flags := add(and(flags, MASK_BIT_COUNT_LOW_64), and(shr(64, flags), MASK_BIT_COUNT_LOW_64))

            //Add every 128 bits in parallel.
            //flags = (flags & MASK_BIT_COUNT_LOW_128) + ((flags >> 128) & MASK_BIT_COUNT_LOW_128);
            flags := add(and(flags, MASK_BIT_COUNT_LOW_128), and(shr(128, flags), MASK_BIT_COUNT_LOW_128))
       }
        return flags;
    }

    /**
     * @dev Returns the index of the given `value` counting from the right, with the `n`th bit set to true.
     */
    function indexOf(uint256 flags, uint256 n) internal pure returns (uint256 rank) {
        require(n <= 0xFF, "Bits: index out of bounds");

        if (flags == 0)
        {
            rank = type(uint256).max;
        }
        else
        {
            rank = 0;

            assembly {
                //n = n + 1;
                n := add(n, 1)

                /* At each step, the range of the addition target is increased and the results are reserved. */
                //uint256 flags0 = flags;
                let flags0 := flags

                //uint256 flags1 = (flags0 & MASK_BIT_COUNT_ALL_5) + ((flags0 >> 1) & MASK_BIT_COUNT_ALL_5);
                let flags1 := add(and(flags0, MASK_BIT_COUNT_ALL_5), and(shr(1, flags0), MASK_BIT_COUNT_ALL_5))

                //uint256 flags2 = (flags1 & MASK_BIT_COUNT_ALL_3) + ((flags1 >> 2) & MASK_BIT_COUNT_ALL_3);
                let flags2 := add(and(flags1, MASK_BIT_COUNT_ALL_3), and(shr(2, flags1), MASK_BIT_COUNT_ALL_3))

                //uint256 flags3 = (flags2 & MASK_BIT_COUNT_LOW_4) + ((flags2 >> 4) & MASK_BIT_COUNT_LOW_4);
                let flags3 := add(and(flags2, MASK_BIT_COUNT_LOW_4), and(shr(4, flags2), MASK_BIT_COUNT_LOW_4))

                //uint256 flags4 = (flags3 & MASK_BIT_COUNT_LOW_8) + ((flags3 >> 8) & MASK_BIT_COUNT_LOW_8);
                let flags4 := add(and(flags3, MASK_BIT_COUNT_LOW_8), and(shr(8, flags3), MASK_BIT_COUNT_LOW_8))

                //uint256 flags5 = (flags4 & MASK_BIT_COUNT_LOW_16) + ((flags4 >> 16) & MASK_BIT_COUNT_LOW_16);
                let flags5 := add(and(flags4, MASK_BIT_COUNT_LOW_16), and(shr(16, flags4), MASK_BIT_COUNT_LOW_16))

                //uint256 flags6 = (flags5 & MASK_BIT_COUNT_LOW_32) + ((flags5 >> 32) & MASK_BIT_COUNT_LOW_32);
                let flags6 := add(and(flags5, MASK_BIT_COUNT_LOW_32), and(shr(32, flags5), MASK_BIT_COUNT_LOW_32))

                //uint256 flags7 = (flags6 & MASK_BIT_COUNT_LOW_64) + ((flags6 >> 64) & MASK_BIT_COUNT_LOW_64);
                let flags7 := add(and(flags6, MASK_BIT_COUNT_LOW_64), and(shr(64, flags6), MASK_BIT_COUNT_LOW_64))


                /* Based on the step-by-step addition results, the index is identified by a binary search. */
                //flags7 & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
                let temp := and(flags7, MASK_BIT_COUNT_LOW_128)

                //if (n > temp) { rank += 128; n -= temp; }
                if gt(n, temp) { rank := add(rank, 128) n := sub(n, temp) }
                //temp = (flags6 >> rank) & 0xFFFFFFFFFFFFFFFF;
                temp := and(shr(rank, flags6), 0xFFFFFFFFFFFFFFFF)

                //if (n > temp) { rank += 64; n -= temp; }
                if gt(n, temp) { rank := add(rank, 64) n := sub(n, temp) }
                //temp = (flags5 >> rank) & 0xFFFFFFFF;
                temp := and(shr(rank, flags5), 0xFFFFFFFF)

                //if (n > temp) { rank += 32; n -= temp; }
                if gt(n, temp) { rank := add(rank, 32) n := sub(n, temp) }
                //temp = (flags4 >> rank) & 0xFFFF;
                temp := and(shr(rank, flags4), 0xFFFF)

                //if (n > temp) { rank += 16; n -= temp; }
                if gt(n, temp) { rank := add(rank, 16) n := sub(n, temp) }
                //temp = (flags3 >> rank) & 0xFF;
                temp := and(shr(rank, flags3), 0xFF)

                //if (n > temp) { rank += 8; n -= temp; }
                if gt(n, temp) { rank := add(rank, 8) n := sub(n, temp) }
                //temp = (flags2 >> rank) & 0x0F;
                temp := and(shr(rank, flags2), 0x0F)

                //if (n > temp) { rank += 4; n -= temp; }
                if gt(n, temp) { rank := add(rank, 4) n := sub(n, temp) }
                //temp = (flags1 >> rank) & 0x03;
                temp := and(shr(rank, flags1), 0x03)

                //if (n > temp) { rank += 2; n -= temp; }
                if gt(n, temp) { rank := add(rank, 2) n := sub(n, temp) }
                //temp = (flags0 >> rank) & 0x01;
                temp := and(shr(rank, flags0), 0x01)

                //if (n > temp) { rank += 1; }
                if gt(n, temp) { rank := add(rank, 1) }
            }
        }
    }
}
