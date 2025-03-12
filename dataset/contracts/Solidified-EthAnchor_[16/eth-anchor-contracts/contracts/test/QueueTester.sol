// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;

import { StdQueue } from "../utils/Queue.sol";

contract QueueTester {
  using StdQueue for StdQueue.Queue;

  StdQueue.Queue public queue;

  function isEmpty() public view returns (bool) {
    return queue._isEmpty();
  }

  function getItemAt(uint256 _index) public view returns (bytes32) {
    return queue._getItemAt(_index);
  }

  function produce(bytes32 _data) public {
    queue._produce(_data);
  }

  function consume() public {
    emit Consumed(queue._consume());
  }

  event Consumed(bytes32);
}
