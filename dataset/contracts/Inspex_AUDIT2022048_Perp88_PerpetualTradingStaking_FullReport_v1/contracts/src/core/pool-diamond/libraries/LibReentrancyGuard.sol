// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library LibReentrancyGuard {
  error LibReentrancyGuard_ReentrantCall();

  // -------------
  //    Constants
  // -------------
  // keccak256("com.perp88.reentrancyguard.diamond.storage")
  bytes32 internal constant REENTRANCY_GUARD_STORAGE_POSITION =
    0xfd6169b5c507ad45678acd2f1b847ecc173862dd71c1994b14dc7b671ec4ff6b;

  uint256 internal constant _NOT_ENTERED = 1;
  uint256 internal constant _ENTERED = 2;

  // -------------
  //    Storage
  // -------------
  struct ReentrancyGuardDiamondStorage {
    uint256 status;
  }

  function reentrancyGuardDiamondStorage()
    internal
    pure
    returns (ReentrancyGuardDiamondStorage storage reentrancyGuardDs)
  {
    assembly {
      reentrancyGuardDs.slot := REENTRANCY_GUARD_STORAGE_POSITION
    }
  }

  function lock() internal {
    ReentrancyGuardDiamondStorage
      storage reentrancyGuardDs = reentrancyGuardDiamondStorage();
    if (reentrancyGuardDs.status == _ENTERED)
      revert LibReentrancyGuard_ReentrantCall();

    reentrancyGuardDs.status = _ENTERED;
  }

  function unlock() internal {
    ReentrancyGuardDiamondStorage
      storage reentrancyGuardDs = reentrancyGuardDiamondStorage();
    reentrancyGuardDs.status = _NOT_ENTERED;
  }
}
