// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

/**
 * Item of Duelist King
 * Name: Item
 * Domain: Duelist King
 */
library DuelistKingItem {
  // We have 256 bits to store an item's id so we dicide to contain as much as posible data
  // Application      64  bits    Some item need the randomnes value as seed to be openned

  // Edition:         16  bits    For now, 0-Standard edition 0xffff-Creator edition
  // Generation:      16  bits    Generation of item, now it's Gen 0
  // Rareness:        16  bits    1-C, 2-U, 3-R, 4-SR, 5-SSR, 6-L
  // Type:            16  bits    Type of item
  // Id:              64  bits    Increasement value that unique for each item
  // Serial:          64  bits    Increasement value that count the number of items
  // 256             192         176             160            144         128       64            0
  //  |  application  |  edition  |  generation   |   rareness   |   type    |   id    |   serial   |
  function set(
    uint256 value,
    uint256 shift,
    uint256 mask,
    uint256 newValue
  ) internal pure returns (uint256 result) {
    require((mask | newValue) ^ mask == 0, 'DuelistKingItem: New value is out range');
    assembly {
      // result = value & not(mask << shift)
      result := and(value, not(shl(shift, mask)))
      // result = result or (newValue << shift)
      result := or(shl(shift, newValue), result)
    }
  }

  function get(
    uint256 value,
    uint256 shift,
    uint256 mask
  ) internal pure returns (uint256 result) {
    assembly {
      // result = ((mask << shift) & value) >> shift
      result := shr(shift, and(value, shl(shift, mask)))
    }
  }

  function setSerial(uint256 a, uint256 b) internal pure returns (uint256 c) {
    return set(a, 0, 0xffffffffffffffff, b);
  }

  function getSerial(uint256 a) internal pure returns (uint256 c) {
    return get(a, 0, 0xffffffffffffffff);
  }

  function setId(uint256 a, uint256 b) internal pure returns (uint256 c) {
    return set(a, 64, 0xffffffffffffffff, b);
  }

  function getId(uint256 a) internal pure returns (uint256 c) {
    return get(a, 64, 0xffffffffffffffff);
  }

  function setType(uint256 a, uint256 b) internal pure returns (uint256 c) {
    return set(a, 128, 0xffff, b);
  }

  function getType(uint256 a) internal pure returns (uint256 c) {
    return get(a, 128, 0xffff);
  }

  function setRareness(uint256 a, uint256 b) internal pure returns (uint256 c) {
    return set(a, 144, 0xffff, b);
  }

  function getRareness(uint256 a) internal pure returns (uint256 c) {
    return get(a, 144, 0xffff);
  }

  function setGeneration(uint256 a, uint256 b) internal pure returns (uint256 c) {
    return set(a, 160, 0xffff, b);
  }

  function getGeneration(uint256 a) internal pure returns (uint256 c) {
    return get(a, 160, 0xffff);
  }

  function setEdition(uint256 a, uint256 b) internal pure returns (uint256 c) {
    return set(a, 176, 0xffff, b);
  }

  function getEdition(uint256 a) internal pure returns (uint256 c) {
    return get(a, 176, 0xffff);
  }

  function setApplicationId(uint256 a, uint256 b) internal pure returns (uint256 c) {
    return set(a, 192, 0xffffffffffffffff, b);
  }

  function getApplicationId(uint256 a) internal pure returns (uint256 c) {
    return get(a, 192, 0xffffffffffffffff);
  }
}
