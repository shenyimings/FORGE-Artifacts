// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;

library StdQueue {
  struct Queue {
    uint256 index;
    uint256 size;
    mapping(uint256 => bytes32) store;
  }

  function _length(Queue storage q) internal view returns (uint256) {
    return q.size;
  }

  function _isEmpty(Queue storage q) internal view returns (bool) {
    return q.size == 0;
  }

  function _getItemAt(Queue storage q, uint256 index)
    internal
    view
    returns (bytes32)
  {
    return q.store[q.index + index];
  }

  function _produce(Queue storage q, bytes32 data) internal {
    q.store[q.index + q.size] = data;
    q.size += 1;
  }

  function _consume(Queue storage q) internal returns (bytes32) {
    require(!_isEmpty(q), "StdQueue: empty queue");
    bytes32 data = _getItemAt(q, 0);
    q.index += 1;
    q.size -= 1;
    return data;
  }

  // ====================== Bytes32 ====================== //

  struct Bytes32Queue {
    Queue _inner;
  }

  function length(Bytes32Queue storage queue) internal view returns (uint256) {
    return _length(queue._inner);
  }

  function isEmpty(Bytes32Queue storage queue) internal view returns (bool) {
    return _isEmpty(queue._inner);
  }

  function getItemAt(Bytes32Queue storage queue, uint256 _index)
    internal
    view
    returns (bytes32)
  {
    return _getItemAt(queue._inner, _index);
  }

  function produce(Bytes32Queue storage queue, bytes32 _value) internal {
    _produce(queue._inner, _value);
  }

  function consume(Bytes32Queue storage queue) internal returns (bytes32) {
    return _consume(queue._inner);
  }

  // ====================== Address ====================== //

  struct AddressQueue {
    Queue _inner;
  }

  function length(AddressQueue storage queue) internal view returns (uint256) {
    return _length(queue._inner);
  }

  function isEmpty(AddressQueue storage queue) internal view returns (bool) {
    return _isEmpty(queue._inner);
  }

  function getItemAt(AddressQueue storage queue, uint256 _index)
    internal
    view
    returns (address)
  {
    return address(uint160(uint256(_getItemAt(queue._inner, _index))));
  }

  function produce(AddressQueue storage queue, address _value) internal {
    _produce(queue._inner, bytes32(uint256(uint160(_value))));
  }

  function consume(AddressQueue storage queue) internal returns (address) {
    return address(uint256(bytes32(_consume(queue._inner))));
  }
}
