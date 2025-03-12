// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IBalancerStrategy {
  function disable (  ) external;
  function getStrategyBalance (  ) external view returns ( uint128 );
  function getStrategyUnderlyingWithRewards (  ) external view returns ( uint128 );
  function globalIndex (  ) external view returns ( uint24 );
  function initialize (  ) external;
  function isAllocationProvider ( address ) external view returns ( bool );
  function isDoHardWorker ( address ) external view returns ( bool );
  function nCoin (  ) external view returns ( uint256 );
  function pool (  ) external view returns ( address );
  function poolId (  ) external view returns ( bytes32 );
  function reallocationIndex (  ) external view returns ( uint24 );
  function underlying (  ) external view returns ( address );
  function vault (  ) external view returns ( address );
  function withdrawalDoHardWorksLeft (  ) external view returns ( uint8 );
}

