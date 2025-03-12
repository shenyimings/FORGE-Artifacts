// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @notice Math library for numbers with basis points (1/10000) precision
library BasisPointNumberMath {
  uint256 public constant BASIS_POINT = 10000; // 10000 in basis points = 100% so 1 is equal to 0.01%

  /// @dev Returns the result of multiplying a number by a basis point number. Used to apply modifiers
  function applyModifierInBasisPoint(
    uint256 _number,
    uint256 _modifierInBasisPoint
  ) internal pure returns (uint256) {
    return (_number * _modifierInBasisPoint) / BASIS_POINT;
  }
}
