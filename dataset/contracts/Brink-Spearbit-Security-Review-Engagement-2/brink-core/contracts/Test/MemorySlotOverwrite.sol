// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.10;
pragma abicoder v1;

/// @dev Test contract to overwrite default memory slots
contract MemorySlotOverwrite {
  bytes32 internal _slot0;
  bytes32 internal _slot1;
  bytes32 internal _slot2;
  bytes32 internal _slot3;
  bytes32 internal _slot4;
  bytes32 internal _slot5;

  function overwrite () external {
    _slot0 = bytes32(0);
    _slot1 = bytes32(0);
    _slot2 = bytes32(0);
    _slot3 = bytes32(0);
    _slot4 = bytes32(0);
    _slot5 = bytes32(0);
  }
}
