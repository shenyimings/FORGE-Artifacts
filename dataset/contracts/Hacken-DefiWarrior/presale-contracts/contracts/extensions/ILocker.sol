// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ILocker {
  /**
   * @dev Fails if transaction is not allowed. Otherwise returns the penalty.
   * Returns a bool and a uint16, bool clarifying the penalty applied, and uint16 the penaltyOver1000
   */
  function checkLock(address source, uint256 remainBalance) external view returns (bool);
}
