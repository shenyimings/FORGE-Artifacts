// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

interface IGelatoAutomation {
  event TaskScheduled(uint256 timestamp, bytes32 taskId);
  event TaskCancelled(uint256 timestamp, bytes32 taskId);

  function createTask() external;

  function cancelTask() external;
}
