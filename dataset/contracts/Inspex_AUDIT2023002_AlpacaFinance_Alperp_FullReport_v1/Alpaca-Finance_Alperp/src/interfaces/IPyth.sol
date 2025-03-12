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

import { IPyth as PythAbstraction } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

interface IPyth is PythAbstraction {
  function priceFeedExists(bytes32 id) external view returns (bool);
}
