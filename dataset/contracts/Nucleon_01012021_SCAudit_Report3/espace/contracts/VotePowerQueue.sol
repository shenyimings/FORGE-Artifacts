//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.2;

library VotePowerQueue {

  struct QueueNode {
    uint xCFXAmounts;
    uint votePower;
    uint endBlock;
  }

  struct InOutQueue {
    uint start;
    uint end;
    mapping(uint => QueueNode) items;
  }

  function enqueue(InOutQueue storage queue, QueueNode memory item) internal {
    queue.items[queue.end++] = item;
  }

  function dequeue(InOutQueue storage queue, uint i) internal returns (QueueNode memory) {
    QueueNode memory item = queue.items[queue.start];
    queue.items[i] = queue.items[queue.start];
    delete queue.items[queue.start++];
    return item;
  }

  function queueLength(InOutQueue storage q) internal view returns (uint length) {
    return  q.end-q.start;
  }
  
  function queueItems(InOutQueue storage q) internal view returns (QueueNode[] memory) {
    QueueNode[] memory items = new QueueNode[](q.end - q.start);
    for (uint i = q.start; i < q.end; i++) {
      items[i - q.start] = q.items[i];
    }
    return items;
  }

  /**
  * Collect all ended vote powers from queue
  */
  function collectEndedVotes(InOutQueue storage q) internal returns (uint) {
    uint total = 0;
    for (uint i = q.start; i < q.end; i++) {
      if (q.items[i].endBlock <= block.number) {
        total += q.items[i].votePower;
        dequeue(q,i);
      }
    }
    return total;
  }

  function sumEndedVotes(InOutQueue storage q) internal view returns (uint) {
    uint total = 0;
    for (uint i = q.start; i < q.end; i++) {
      if (q.items[i].endBlock <= block.number) {
        total += q.items[i].votePower;
      }
    }
    return total;
  }
}