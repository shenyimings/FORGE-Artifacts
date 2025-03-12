// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;
pragma experimental ABIEncoderV2;

import { EnumerableSet } from "@openzeppelin/contracts/utils/EnumerableSet.sol";

import { StdQueue } from "../utils/Queue.sol";
import { IOperation } from "./Operation.sol";
import { OperationACL } from "./OperationACL.sol";

interface IOperationStore {
  // Events
  event OperationAllocated(
    address indexed controller,
    address indexed operation
  );
  event OperationInitialized(
    address indexed controller,
    address indexed operation,
    bool autoFinish
  );
  event OperationFinished(
    address indexed controller,
    address indexed operation
  );
  event OperationStopped(address indexed controller, address indexed operation);
  event OperationRecovered(
    address indexed controller,
    address indexed operation
  );
  event OperationDeallocated(
    address indexed controller,
    address indexed operation
  );
  event OperationFlushed(
    address indexed controller,
    address indexed operation,
    Queue from,
    Queue to
  );

  // Data Structure
  enum Status {
    IDLE,
    RUNNING_AUTO,
    RUNNING_MANUAL,
    FINISHED,
    STOPPED,
    RECOVERED,
    DEALLOCATED
  }

  enum Queue {
    IDLE,
    RUNNING,
    STOPPED,
    NULL
  }

  // getter
  function getAvailableOperation() external view returns (address);

  function getQueuedOperationAt(Queue _queue, uint256 _index)
    external
    view
    returns (address);

  function getQueueSizeOf(Queue _queue) external view returns (uint256);

  function getStatusOf(address _opt) external view returns (Status);

  // logics
  function allocate(address _opt) external;

  function init(bool _autoFinish) external returns (address);

  function finish(address _opt) external;

  function halt(address _opt) external;

  function recover(address _opt) external;

  function deallocate(address _opt) external;

  // queue
  function flush(Queue queue, uint256 _amount) external;

  function flushAll(uint256 _amount) external; // running, failed
}

contract OperationStore is IOperationStore, OperationACL {
  using StdQueue for StdQueue.AddressQueue;
  using EnumerableSet for EnumerableSet.AddressSet;

  // queues
  mapping(address => Status) public optStat;

  EnumerableSet.AddressSet internal optIdle;
  StdQueue.AddressQueue internal optStopped;
  StdQueue.AddressQueue internal optRunning;

  function getAvailableOperation() public view override returns (address) {
    if (optIdle.length() == 0) {
      return address(0x0);
    }
    return optIdle.at(0);
  }

  function getQueuedOperationAt(Queue _queue, uint256 _index)
    public
    view
    override
    returns (address)
  {
    if (_queue == Queue.IDLE) {
      return optIdle.at(_index);
    } else if (_queue == Queue.RUNNING) {
      return optRunning.getItemAt(_index);
    } else if (_queue == Queue.STOPPED) {
      return optStopped.getItemAt(_index);
    } else {
      revert("OperationStore: invalid queue type");
    }
  }

  function getQueueSizeOf(Queue _queue) public view override returns (uint256) {
    if (_queue == Queue.IDLE) {
      return optIdle.length();
    } else if (_queue == Queue.RUNNING) {
      return optRunning.length();
    } else if (_queue == Queue.STOPPED) {
      return optStopped.length();
    } else {
      revert("OperationStore: invalid queue type");
    }
  }

  function getStatusOf(address _opt) public view override returns (Status) {
    return optStat[_opt];
  }

  // lifecycle

  // x -> init
  function allocate(address _opt) public override onlyGranted {
    optIdle.add(_opt);
    optStat[_opt] = Status.IDLE;
    emit OperationAllocated(msg.sender, _opt);
  }

  // =========================== RUNNING QUEUE OPERATIONS =========================== //

  // init -> finish -> idle
  //      -> fail -> ~
  //      -> x (if autoFinish disabled)
  function init(bool _autoFinish) public override onlyRouter returns (address) {
    // consume
    address opt = optIdle.at(0);
    optIdle.remove(opt);

    if (_autoFinish) {
      optRunning.produce(opt); // idle -> running
      optStat[opt] = Status.RUNNING_AUTO;
    } else {
      optStat[opt] = Status.RUNNING_MANUAL;
    }

    emit OperationInitialized(msg.sender, opt, _autoFinish);
    return opt;
  }

  // =========================== RUNNING QUEUE OPERATIONS =========================== //

  function finish(address _opt) public override onlyGranted {
    Status status = optStat[_opt];

    if (status == Status.RUNNING_MANUAL) {
      allocate(_opt);
    } else if (status == Status.RUNNING_AUTO) {
      // wait for flush
      optStat[_opt] = Status.FINISHED;
    } else {
      revert("Router: invalid condition for finish operation");
    }

    emit OperationFinished(msg.sender, _opt);
  }

  // fail -> recover -> idle
  //      -> deallocate -> x
  function halt(address _opt) public override onlyController {
    Status stat = optStat[_opt];
    if (stat == Status.IDLE) {
      // push to failed queue
      optIdle.remove(_opt);
      optStopped.produce(_opt);
    }
    optStat[_opt] = Status.STOPPED;
    emit OperationStopped(msg.sender, _opt);
  }

  function flushRunningQueue(StdQueue.AddressQueue storage _queue)
    internal
    returns (bool)
  {
    address opt = _queue.getItemAt(0);
    Status stat = optStat[opt];
    if (stat == Status.FINISHED) {
      optIdle.add(_queue.consume());
      optStat[opt] = Status.IDLE;
      emit OperationFlushed(msg.sender, opt, Queue.RUNNING, Queue.IDLE);
    } else if (stat == Status.STOPPED) {
      optStopped.produce(_queue.consume());
      emit OperationFlushed(msg.sender, opt, Queue.RUNNING, Queue.STOPPED);
    } else {
      return false; // RUNNING
    }
    return true;
  }

  // =========================== FAIL QUEUE OPERATIONS =========================== //

  function recover(address _opt) public override onlyController {
    optStat[_opt] = Status.RECOVERED;
    emit OperationRecovered(msg.sender, _opt);
  }

  function deallocate(address _opt) public override onlyController {
    optStat[_opt] = Status.DEALLOCATED;
    emit OperationDeallocated(msg.sender, _opt);
  }

  function flushStoppedQueue(StdQueue.AddressQueue storage _queue)
    internal
    returns (bool)
  {
    address opt = _queue.getItemAt(0);
    Status stat = optStat[opt];
    if (stat == Status.RECOVERED) {
      optIdle.add(_queue.consume());
      optStat[opt] = Status.IDLE;
      emit OperationFlushed(msg.sender, opt, Queue.STOPPED, Queue.IDLE);
    } else if (stat == Status.DEALLOCATED) {
      _queue.consume();
      emit OperationFlushed(msg.sender, opt, Queue.STOPPED, Queue.NULL);
    } else {
      return false; // STOPPED
    }

    return true;
  }

  function _flush(
    StdQueue.AddressQueue storage _queue,
    uint256 _amount,
    function(StdQueue.AddressQueue storage) returns (bool) _handler
  ) internal {
    for (uint256 i = 0; i < _amount; i++) {
      if (_queue.isEmpty()) {
        return;
      }

      if (!_handler(_queue)) {
        return;
      }
    }
  }

  function flush(Queue _queue, uint256 _amount) public override onlyController {
    if (_queue == Queue.RUNNING) {
      _flush(optRunning, _amount, flushRunningQueue);
    } else if (_queue == Queue.STOPPED) {
      _flush(optStopped, _amount, flushStoppedQueue);
    } else {
      revert("OperationStore: invalid queue type");
    }
  }

  function flushAll(uint256 _amount) public override onlyController {
    flush(Queue.RUNNING, _amount);
    flush(Queue.STOPPED, _amount);
  }
}
