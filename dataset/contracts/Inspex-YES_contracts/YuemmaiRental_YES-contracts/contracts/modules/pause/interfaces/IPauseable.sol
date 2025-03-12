// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IPauseable {
  event Paused(address account);
  event Unpaused(address account);

  function paused() external view returns (bool);

  function pause() external;
  function unpause() external; 
}