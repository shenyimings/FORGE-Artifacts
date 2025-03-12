// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

interface IAbracadabraMetapoolStrategy {
  function depositZap (  ) external view returns ( address );
  function disable (  ) external;
  function farm (  ) external view returns ( address );
  function farmHelper (  ) external view returns ( address );
  function getStrategyBalance (  ) external view returns ( uint128 );
  function getStrategyUnderlyingWithRewards (  ) external view returns ( uint128 );
  function globalIndex (  ) external view returns ( uint24 );
  function initialize (  ) external;
  function isAllocationProvider ( address ) external view returns ( bool );
  function isDoHardWorker ( address ) external view returns ( bool );
  function lpToken (  ) external view returns ( address );
  function nCoin (  ) external view returns ( int128 );
  function pool (  ) external view returns ( address );
  function reallocationIndex (  ) external view returns ( uint24 );
  function rewardToken (  ) external view returns ( address );
  function underlying (  ) external view returns ( address );
  function withdrawalDoHardWorksLeft (  ) external view returns ( uint8 );
}

