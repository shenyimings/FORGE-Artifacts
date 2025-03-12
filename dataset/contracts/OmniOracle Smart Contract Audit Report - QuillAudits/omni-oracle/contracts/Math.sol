// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

// a library for performing various math operations

library Math {
  uint256 public constant BONE = 10**18;
  uint256 public constant TWO_BONES = 2 * 10**18;

  /**
   * @notice Returns the square root of an uint256 x using the Babylonian method
   * @param y The number to calculate the sqrt from
   * @param bone True when y has 18 decimals
   */
  function bsqrt(uint256 y, bool bone) internal pure returns (uint256 z) {
    if (y > 3) {
      z = y;
      uint256 x = y / 2 + 1;
      while (x < z) {
        z = x;
        if (bone) {
          x = (bdiv(y, x) + x) / 2;
        } else {
          x = (y / x + x) / 2;
        }
      }
    } else if (y != 0) {
      z = 1;
    }
  }

  function bmul(
    uint256 a,
    uint256 b //Bone mul
  ) internal pure returns (uint256) {
    uint256 c0 = a * b;
    require(a == 0 || c0 / a == b, 'ERR_MUL_OVERFLOW');
    uint256 c1 = c0 + (BONE / 2);
    require(c1 >= c0, 'ERR_MUL_OVERFLOW');
    uint256 c2 = c1 / BONE;
    return c2;
  }

  function bdiv(
    uint256 a,
    uint256 b //Bone div
  ) internal pure returns (uint256) {
    require(b != 0, 'ERR_DIV_ZERO');
    uint256 c0 = a * BONE;
    require(a == 0 || c0 / a == BONE, 'ERR_DIV_INTERNAL'); // bmul overflow
    uint256 c1 = c0 + (b / 2);
    require(c1 >= c0, 'ERR_DIV_INTERNAL'); //  badd require
    uint256 c2 = c1 / b;
    return c2;
  }
}
