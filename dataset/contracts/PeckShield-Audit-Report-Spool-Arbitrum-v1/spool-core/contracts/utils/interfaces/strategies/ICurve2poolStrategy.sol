// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

interface ICurve2poolStrategy {
  function disable (  ) external;
  function gaugeHelper (  ) external view returns ( address );
  function getStrategyBalance (  ) external view returns ( uint128 );
  function getStrategyUnderlyingWithRewards (  ) external view returns ( uint128 );
  function globalIndex (  ) external view returns ( uint24 );
  function initialize (  ) external;
  function isAllocationProvider ( address ) external view returns ( bool );
  function isDoHardWorker ( address ) external view returns ( bool );
  function lpToken (  ) external view returns ( address );
  function nCoin (  ) external view returns ( int128 );
  function pool (  ) external view returns ( address );
  function pool2Coins (  ) external view returns ( address );
  function reallocationIndex (  ) external view returns ( uint24 );
  function underlying (  ) external view returns ( address );
  function withdrawalDoHardWorksLeft (  ) external view returns ( uint8 );
}

