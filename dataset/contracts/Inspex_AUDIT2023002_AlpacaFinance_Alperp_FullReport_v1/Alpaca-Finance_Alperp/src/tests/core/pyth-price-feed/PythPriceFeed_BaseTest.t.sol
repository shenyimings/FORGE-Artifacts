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

import { BaseTest, console, PoolOracle, FakePyth, PythPriceFeed } from "../../base/BaseTest.sol";

import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

abstract contract PythPriceFeed_BaseTest is BaseTest {
  PythPriceFeed internal pythPriceFeed;
  IPyth internal pyth;

  uint256 internal constant FEE = 0.01 ether;

  function setUp() public virtual {
    pyth = deployFakePyth(1, FEE); // no older than 1 sec for getPrice, 0.01 for fee
    pythPriceFeed = deployPythPriceFeed(address(pyth));
  }
}
