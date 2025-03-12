// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import './interfaces/IGelatoAutomation.sol';

abstract contract GelatoAutomation is IGelatoAutomation {
  bytes32 public automationTaskId;
}
