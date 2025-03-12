// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { BaseTest } from "../base/BaseTest.sol";
import { P88 } from "../../tokens/P88.sol";

contract P88Test is BaseTest {
  P88 internal p88;

  function setUp() external {
    p88 = new P88(true);
  }

  function testCorrectness_init() external {
    assertEq(p88.name(), "Perp88");
    assertEq(p88.symbol(), "P88");
  }

  function testCorrectness_setMinter() external {
    assertFalse(p88.isMinter(ALICE));
    p88.setMinter(ALICE, true);
    assertTrue(p88.isMinter(ALICE));
  }

  function testCorrectness_mint() external {
    p88.setMinter(ALICE, true);
    vm.startPrank(ALICE);
    p88.mint(BOB, 88 ether);
    assertEq(p88.balanceOf(BOB), 88 ether);
    vm.stopPrank();
  }

  function testRevert_mint() external {
    vm.expectRevert(abi.encodeWithSignature("BaseMintableToken_NotMinter()"));
    p88.mint(BOB, 88 ether);
  }

  function testRevert_burn() external {
    vm.expectRevert(abi.encodeWithSignature("BaseMintableToken_NotMinter()"));
    p88.burn(BOB, 88 ether);
  }
}
