// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../proxy/ControllableV3.sol";

contract SlotsTest is ControllableV3 {
  struct SomeStruct {
    uint a;
    uint b;
  }

  bytes32 internal constant _SLOT = bytes32(uint256(keccak256("slot")) - 1);

  mapping(uint => SomeStruct) public map;

  function initialize(address controller_) external initializer {
    __Controllable_init(controller_);
  }

  function setMapA(uint index, uint a) external {
    map[index].a = a;
  }

  function getBytes32() external view returns (bytes32 result) {
    return SlotsLib.getBytes32(_SLOT);
  }

  function getAddress() external view returns (address result) {
    return SlotsLib.getAddress(_SLOT);
  }

  function getUint() external view returns (uint result) {
    return SlotsLib.getUint(_SLOT);
  }

  function arrayLength() external view returns (uint result) {
    return SlotsLib.arrayLength(_SLOT);
  }

  function addressAt(uint index) external view returns (address result) {
    return SlotsLib.addressAt(_SLOT, index);
  }

  function uintAt(uint index) external view returns (uint result) {
    return SlotsLib.uintAt(_SLOT, index);
  }

  function setByte32(bytes32 value) external {
    SlotsLib.set(_SLOT, value);
  }

  function setAddress(address value) external {
    SlotsLib.set(_SLOT, value);
  }

  function setUint(uint value) external {
    SlotsLib.set(_SLOT, value);
  }

  function setAt(uint index, address value) external {
    SlotsLib.setAt(_SLOT, index, value);
  }

  function setAt(uint index, uint value) external {
    SlotsLib.setAt(_SLOT, index, value);
  }

  function setLength(uint length) external {
    SlotsLib.setLength(_SLOT, length);
  }

  function push(address value) external {
    SlotsLib.push(_SLOT, value);
  }

}


/// @dev extending SomeStruct with new member
contract SlotsTest2 is ControllableV3 {
  struct SomeStruct {
    uint a;
    uint b;
  }

  mapping(uint => SomeStruct) public map;

  function initialize(address controller_) external initializer {
    __Controllable_init(controller_);
  }

  function setMapA(uint index, uint a) external {
    map[index].a = a;
  }

  function setMapB(uint index, uint b) external {
    map[index].b = b;
  }

}
