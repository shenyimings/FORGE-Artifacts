// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IConvexSharedStrategy {
  function booster (  ) external view returns ( address );
  function boosterHelper (  ) external view returns ( address );
  function crvRewards (  ) external view returns ( address );
  function cvxToken (  ) external view returns ( address );
  function disable (  ) external;
  function emergencyWithdraw ( address recipient, uint256[] memory data ) external;
  function getStrategyBalance (  ) external view returns ( uint128 );
  function getStrategyUnderlyingWithRewards (  ) external view returns ( uint128 );
  function globalIndex (  ) external view returns ( uint24 );
  function initialize (  ) external;
  function isAllocationProvider ( address ) external view returns ( bool );
  function isDoHardWorker ( address ) external view returns ( bool );
  function lpToken (  ) external view returns ( address );
  function nCoin (  ) external view returns ( int128 );
  function pid (  ) external view returns ( uint256 );
  function pool (  ) external view returns ( address );
  function pool3Coins (  ) external view returns ( address );
  function processDeposit ( uint256[] memory slippages ) external;
  function reallocationIndex (  ) external view returns ( uint24 );
  function rewardToken (  ) external view returns ( address );
  function underlying (  ) external view returns ( address );
  function withdrawalDoHardWorksLeft (  ) external view returns ( uint8 );
}
