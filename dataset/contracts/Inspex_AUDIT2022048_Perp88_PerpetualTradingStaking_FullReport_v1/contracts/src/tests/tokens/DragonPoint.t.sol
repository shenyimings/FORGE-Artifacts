// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { BaseTest, console } from "../base/BaseTest.sol";
import { DragonPoint } from "../../tokens/DragonPoint.sol";

contract DragonPointTest is BaseTest {
  DragonPoint internal dp;

  function setUp() external {
    dp = deployDragonPoint();
  }

  function testCorrectness_init() external {
    assertEq(dp.name(), "Dragon Point");
    assertEq(dp.symbol(), "DP");
  }

  function testCorrectness_setMinter() external {
    assertFalse(dp.isMinter(ALICE));
    dp.setMinter(ALICE, true);
    assertTrue(dp.isMinter(ALICE));
  }

  function testCorrectness_mint() external {
    dp.setMinter(ALICE, true);
    vm.startPrank(ALICE);
    dp.mint(BOB, 88 ether);
    assertEq(dp.balanceOf(BOB), 88 ether);
    vm.stopPrank();
  }

  function testRevert_mint() external {
    vm.expectRevert(abi.encodeWithSignature("DragonPoint_NotMinter()"));
    dp.mint(BOB, 88 ether);
  }

  function testCorrectness_burn() external {
    dp.setMinter(ALICE, true);
    vm.startPrank(ALICE);
    dp.mint(BOB, 88 ether);
    assertEq(dp.balanceOf(BOB), 88 ether);
    dp.burn(BOB, 88 ether);
    assertEq(dp.balanceOf(BOB), 0 ether);
    vm.stopPrank();
  }

  function testRevert_burn() external {
    vm.expectRevert(abi.encodeWithSignature("DragonPoint_NotMinter()"));
    dp.burn(BOB, 88 ether);
  }

  function test_WhenAliceBobTransferToken_BothWhitelisted_ShouldWork()
    external
  {
    dp.setMinter(ALICE, true);
    vm.startPrank(ALICE);
    dp.mint(BOB, 88 ether);
    vm.stopPrank();

    // ALICE: 0 MPT
    // BOB: 88 MPT
    assertEq(dp.balanceOf(ALICE), 0 ether);
    assertEq(dp.balanceOf(BOB), 88 ether);

    // Whitelist both
    dp.setTransferrer(ALICE, true);
    dp.setTransferrer(BOB, true);
    // Transfer BOB <-> ALICE
    vm.startPrank(BOB);
    dp.transfer(ALICE, 40 ether); // BOB -> ALICE 40
    vm.stopPrank();
    vm.startPrank(ALICE);
    dp.approve(ALICE, 2 ether);
    dp.transferFrom(ALICE, BOB, 2 ether); // ALICE -> BOB 2
    vm.stopPrank();

    // ALICE: 38 MPT
    // BOB: 50 MPT
    assertEq(dp.balanceOf(ALICE), 38 ether);
    assertEq(dp.balanceOf(BOB), 50 ether);
  }

  function test_WhenAliceBobTransferToken_NoneWhitelisted_ShouldFail()
    external
  {
    dp.setMinter(ALICE, true);
    vm.startPrank(ALICE);
    dp.mint(ALICE, 44 ether);
    dp.mint(BOB, 88 ether);
    vm.stopPrank();

    // Whitelist no one
    // Transfer BOB <-> ALICE
    vm.startPrank(BOB);
    vm.expectRevert(abi.encodeWithSignature("DragonPoint_isNotTransferrer()"));
    dp.transfer(ALICE, 1 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("DragonPoint_isNotTransferrer()"));
    dp.transfer(BOB, 1 ether);
    vm.stopPrank();
  }
}
