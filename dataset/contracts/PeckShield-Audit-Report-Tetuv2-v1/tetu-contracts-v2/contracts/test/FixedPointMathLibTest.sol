// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../lib/FixedPointMathLib.sol";

contract FixedPointMathLibTest {

  function mulWadDown(uint x, uint y) external pure returns (uint) {
    return FixedPointMathLib.mulWadDown(x, y);
  }

  function mulWadUp(uint x, uint y) external pure returns (uint) {
    return FixedPointMathLib.mulWadUp(x, y);
  }

  function rpow(
    uint x,
    uint n,
    uint scalar
  ) external pure returns (uint) {
    return FixedPointMathLib.rpow(x, n, scalar);
  }

  function sqrt(uint x) external pure returns (uint) {
    return FixedPointMathLib.sqrt(x);
  }

}
