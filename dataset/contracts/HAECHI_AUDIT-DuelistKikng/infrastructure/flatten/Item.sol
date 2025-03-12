// Root file: contracts/libraries/Item.sol

// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;

library Item {
  // We have 256 bits to store a Item id so we dicide to contain as much as posible data
  // Application ID:      64 bits
  function set(
    uint256 value,
    uint256 shift,
    uint256 mask,
    uint256 newValue
  ) internal pure returns (uint256 result) {
    require((mask | newValue) ^ mask == 0, 'Item: New value is out range');
    assembly {
      result := and(value, not(shl(shift, mask)))
      result := or(shl(shift, newValue), result)
    }
  }

  function get(
    uint256 value,
    uint256 shift,
    uint256 mask
  ) internal pure returns (uint256 result) {
    assembly {
      result := shr(shift, and(value, shl(shift, mask)))
    }
  }

  // 256                    192                0
  //  |<-- Application ID -->|<-- Item data -->|
  function setApplicationId(uint256 a, uint256 b) internal pure returns (uint256 c) {
    return set(a, 192, 0xffffffffffffffff, b);
  }

  function getApplicationId(uint256 a) internal pure returns (uint256 c) {
    return get(a, 192, 0xffffffffffffffff);
  }
}
