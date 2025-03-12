// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

interface IEmergencyAccess {
  function setPaused(bool paused) external; // for emergency admin

  function isPaused() external view returns (bool);

  event EmergencyPaused(address indexed by, bool paused);
}
