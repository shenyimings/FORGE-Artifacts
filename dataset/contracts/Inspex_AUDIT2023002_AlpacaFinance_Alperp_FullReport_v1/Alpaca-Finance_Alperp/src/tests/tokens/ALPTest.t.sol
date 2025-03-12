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

pragma solidity >=0.8.4 <0.9.0;

import { BaseTest } from "../base/BaseTest.sol";
import { ALP } from "../../tokens/ALP.sol";

contract ALPTest is BaseTest {
  ALP internal alp;

  function setUp() external {
    alp = deployALP();
  }

  function testCorrectness_setMinter() external {
    assertFalse(alp.isMinter(ALICE));
    alp.setMinter(ALICE, true);
    assertTrue(alp.isMinter(ALICE));
  }

  function testCorrectness_mint() external {
    alp.setMinter(ALICE, true);
    vm.startPrank(ALICE);
    alp.mint(BOB, 88 ether);
    assertEq(alp.balanceOf(BOB), 88 ether);
    vm.stopPrank();
  }

  function testCorrectness_setLiquidityCooldown() external {
    alp.setLiquidityCooldown(2 days);
    assertEq(alp.liquidityCooldown(), 2 days);
  }

  function testRevert_setLiquidityCooldown() external {
    vm.expectRevert(
      abi.encodeWithSelector(ALP.ALP_BadLiquidityCooldown.selector, 3 days)
    );

    alp.setLiquidityCooldown(3 days);
  }

  function testRevert_mint() external {
    vm.expectRevert(abi.encodeWithSignature("ALP_NotMinter()"));
    alp.mint(BOB, 88 ether);
  }

  function testRevert_burn() external {
    vm.expectRevert(abi.encodeWithSignature("ALP_NotMinter()"));
    alp.burn(BOB, 88 ether);
  }

  function testRevert_transferBeforeCooldownExpire() external {
    alp.setMinter(address(this), true);
    alp.mint(BOB, 88 ether);
    vm.startPrank(BOB);
    vm.expectRevert(
      abi.encodeWithSelector(
        ALP.ALP_Cooldown.selector,
        block.timestamp + 1 days
      )
    );
    alp.transfer(ALICE, 88 ether);
    vm.stopPrank();
  }
}
