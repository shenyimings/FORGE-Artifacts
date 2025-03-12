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

import { PoolDiamond_BaseTest, console, OwnershipFacetInterface } from "./PoolDiamond_BaseTest.t.sol";

contract PoolDiamond_OwnerTest is PoolDiamond_BaseTest {
  OwnershipFacetInterface internal poolOwnershipFacet;

  function setUp() public override {
    super.setUp();

    poolOwnershipFacet = OwnershipFacetInterface(poolDiamond);
  }

  function testCorrectness_WhenPoolDiamondIsDeployed() external {
    assertEq(poolOwnershipFacet.owner(), address(this));
  }

  function testCorrectness_WhenTransferToNewOwner() external {
    poolOwnershipFacet.transferOwnership(ALICE);
    assertEq(poolOwnershipFacet.owner(), ALICE);
  }
}
