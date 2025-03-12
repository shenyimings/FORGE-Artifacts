// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { BaseTest } from "../base/BaseTest.sol";
import { PLP } from "../../tokens/PLP.sol";

contract PLPTest is BaseTest {
  PLP internal plp;

  function setUp() external {
    plp = deployPLP();
  }

  function testCorrectness_setMinter() external {
    assertFalse(plp.isMinter(ALICE));
    plp.setMinter(ALICE, true);
    assertTrue(plp.isMinter(ALICE));
  }

  function testCorrectness_mint() external {
    plp.setMinter(ALICE, true);
    vm.startPrank(ALICE);
    plp.mint(BOB, 88 ether);
    assertEq(plp.balanceOf(BOB), 88 ether);
    vm.stopPrank();
  }

  function testCorrectness_setLiquidityCooldown() external {
    plp.setLiquidityCooldown(2 days);
    assertEq(plp.liquidityCooldown(), 2 days);
  }

  function testRevert_setLiquidityCooldown() external {
    vm.expectRevert(
      abi.encodeWithSelector(PLP.PLP_BadLiquidityCooldown.selector, 3 days)
    );

    plp.setLiquidityCooldown(3 days);
  }

  function testRevert_mint() external {
    vm.expectRevert(abi.encodeWithSignature("PLP_NotMinter()"));
    plp.mint(BOB, 88 ether);
  }

  function testRevert_burn() external {
    vm.expectRevert(abi.encodeWithSignature("PLP_NotMinter()"));
    plp.burn(BOB, 88 ether);
  }

  function testRevert_transferBeforeCooldownExpire() external {
    plp.setMinter(address(this), true);
    plp.mint(BOB, 88 ether);
    vm.startPrank(BOB);
    vm.expectRevert(
      abi.encodeWithSelector(
        PLP.PLP_Cooldown.selector,
        block.timestamp + 1 days
      )
    );
    plp.transfer(ALICE, 88 ether);
    vm.stopPrank();
  }
}
