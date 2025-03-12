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

import { PoolOracle_BaseTest } from "./PoolOracle_BaseTest.t.sol";

contract PoolOracle_SetRoundDepthTest is PoolOracle_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function testRevert_WhenRandomUserTryToSetRoundDepth() external {
    vm.prank(ALICE);
    vm.expectRevert("Ownable: caller is not the owner");
    poolOracle.setRoundDepth(0);
  }

  function testRevert_WhenRoundDepthIsInvalid() external {
    vm.expectRevert(abi.encodeWithSignature("PoolOracle_BadArguments()"));
    poolOracle.setRoundDepth(0);
  }

  function testCorrectness_WhenParamsValid() external {
    poolOracle.setRoundDepth(3);
    assertEq(poolOracle.roundDepth(), 3);
  }
}
