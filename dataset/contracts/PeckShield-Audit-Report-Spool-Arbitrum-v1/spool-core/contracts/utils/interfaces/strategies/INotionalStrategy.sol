
// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface INotionalStrategy {
  function getStrategyBalance () external view returns ( uint128 );
  function id () external view returns ( uint16 );
  function nToken () external view returns ( address );
  function notional () external view returns ( address );
  function strategyHelper () external view returns ( address );
  function underlying () external view returns ( address );
}

