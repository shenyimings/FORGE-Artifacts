// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.4.0;

library BitMath {
  // using overflow to get the max uint value
  uint128 private constant UINT128_MAX = uint128(0) - 1;
  uint64 private constant UINT64_MAX = uint64(0) - 1;
  uint32 private constant UINT32_MAX = uint32(0) - 1;
  uint16 private constant UINT16_MAX = uint16(0) - 1;
  uint8 private constant UINT8_MAX = uint8(0) - 1;

  // returns the 0 indexed position of the most significant bit of the input x
  // s.t. x >= 2**msb and x < 2**(msb+1)
  function mostSignificantBit(uint256 x) internal pure returns (uint8 r) {
    require(x > 0, 'BitMath::mostSignificantBit: zero');

    if (x >= 0x100000000000000000000000000000000) {
      x >>= 128;
      r += 128;
    }
    if (x >= 0x10000000000000000) {
      x >>= 64;
      r += 64;
    }
    if (x >= 0x100000000) {
      x >>= 32;
      r += 32;
    }
    if (x >= 0x10000) {
      x >>= 16;
      r += 16;
    }
    if (x >= 0x100) {
      x >>= 8;
      r += 8;
    }
    if (x >= 0x10) {
      x >>= 4;
      r += 4;
    }
    if (x >= 0x4) {
      x >>= 2;
      r += 2;
    }
    if (x >= 0x2) r += 1;
  }

  // returns the 0 indexed position of the least significant bit of the input x
  // s.t. (x & 2**lsb) != 0 and (x & (2**(lsb) - 1)) == 0)
  // i.e. the bit at the index is set and the mask of all lower bits is 0
  function leastSignificantBit(uint256 x) internal pure returns (uint8 r) {
    require(x > 0, 'BitMath::leastSignificantBit: zero');

    r = 255;
    if (x & UINT128_MAX > 0) {
      r -= 128;
    } else {
      x >>= 128;
    }
    if (x & UINT64_MAX > 0) {
      r -= 64;
    } else {
      x >>= 64;
    }
    if (x & UINT32_MAX > 0) {
      r -= 32;
    } else {
      x >>= 32;
    }
    if (x & UINT16_MAX > 0) {
      r -= 16;
    } else {
      x >>= 16;
    }
    if (x & UINT8_MAX > 0) {
      r -= 8;
    } else {
      x >>= 8;
    }
    if (x & 0xf > 0) {
      r -= 4;
    } else {
      x >>= 4;
    }
    if (x & 0x3 > 0) {
      r -= 2;
    } else {
      x >>= 2;
    }
    if (x & 0x1 > 0) r -= 1;
  }
}
