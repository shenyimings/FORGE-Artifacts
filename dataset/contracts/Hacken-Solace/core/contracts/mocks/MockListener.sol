// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.6;

import "./../interfaces/staking/IxsListener.sol";

/**
 * @title MockListener
 * @author solace.fi
 * @notice Mock listener for testing xsLocker.
 */
contract MockListener is IxsListener {

  event Updated(uint256 blocknum, address caller, uint256 xsLockID);

  struct LastUpdate {
      uint256 blocknum;
      address caller;
      uint256 xsLockID;
      address oldOwner;
      address newOwner;
      Lock oldLock;
      Lock newLock;
  }

  LastUpdate public lastUpdate;

  /**
   * @notice Called when an action is performed on a lock.
   * @dev Called on transfer, mint, burn, and update.
   * Either the owner will change or the lock will change, not both.
   * @param xsLockID The ID of the lock that was altered.
   * @param oldOwner The old owner of the lock.
   * @param newOwner The new owner of the lock.
   * @param oldLock The old lock data.
   * @param newLock The new lock data.
   */
  function registerLockEvent(uint256 xsLockID, address oldOwner, address newOwner, Lock calldata oldLock, Lock calldata newLock) external override {
      lastUpdate = LastUpdate({
          blocknum: block.number,
          caller: msg.sender,
          xsLockID: xsLockID,
          oldOwner: oldOwner,
          newOwner: newOwner,
          oldLock: oldLock,
          newLock: newLock
      });
      emit Updated(block.number, msg.sender, xsLockID);
  }
}
