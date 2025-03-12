// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/

pragma solidity 0.8.17;

library LibReentrancyGuard {
  error LibReentrancyGuard_ReentrantCall();

  // -------------
  //    Constants
  // -------------
  // keccak256("com.alperp.reentrancyguard.diamond.storage")
  bytes32 internal constant REENTRANCY_GUARD_STORAGE_POSITION =
    0x2fa1652744cd206d89d3e37a86d4d33cb54d0f086079f57f9749f40bf12e0ed9;

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
