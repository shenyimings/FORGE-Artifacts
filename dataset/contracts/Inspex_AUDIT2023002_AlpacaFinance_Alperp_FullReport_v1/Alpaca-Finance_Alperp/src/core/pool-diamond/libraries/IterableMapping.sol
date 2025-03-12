// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

enum OrderType {
  SWAP,
  INCREASE,
  DECREASE
}

struct Orders {
  address account;
  uint256 subAccountId;
  uint256 orderIndex;
  OrderType orderType;
}

struct IndexValue {
  uint256 keyIndex;
  Orders value;
}
struct KeyFlag {
  uint256 key;
  bool deleted;
}

struct itmap {
  mapping(uint256 => IndexValue) data;
  KeyFlag[] keys;
  uint256 size;
}

library IterableMapping {
  function insert(
    itmap storage self,
    uint256 key,
    Orders memory value
  ) internal returns (bool replaced) {
    uint256 keyIndex = self.data[key].keyIndex;
    self.data[key].value = value;
    if (keyIndex > 0) return true;
    else {
      keyIndex = self.keys.length;
      self.keys.push();
      self.data[key].keyIndex = keyIndex + 1;
      self.keys[keyIndex].key = key;
      self.size++;
      return false;
    }
  }

  function remove(itmap storage self, uint256 key)
    internal
    returns (bool success)
  {
    uint256 keyIndex = self.data[key].keyIndex;
    if (keyIndex == 0) return false;
    delete self.data[key];
    self.keys[keyIndex - 1].deleted = true;
    self.size--;
  }

  function contains(itmap storage self, uint256 key)
    internal
    view
    returns (bool)
  {
    return self.data[key].keyIndex > 0;
  }

  function iterate_start(itmap storage self)
    internal
    view
    returns (uint256 keyIndex)
  {
    return iterate_next(self, 0);
  }

  function iterate_valid(itmap storage self, uint256 keyIndex)
    internal
    view
    returns (bool)
  {
    return keyIndex < self.keys.length;
  }

  function iterate_next(itmap storage self, uint256 keyIndex)
    internal
    view
    returns (uint256 r_keyIndex)
  {
    while (keyIndex < self.keys.length && self.keys[keyIndex].deleted)
      keyIndex++;
    return keyIndex;
  }

  function iterate_get(itmap storage self, uint256 keyIndex)
    internal
    view
    returns (uint256 key, Orders memory value)
  {
    key = self.keys[keyIndex].key;
    value = self.data[key].value;
  }
}
