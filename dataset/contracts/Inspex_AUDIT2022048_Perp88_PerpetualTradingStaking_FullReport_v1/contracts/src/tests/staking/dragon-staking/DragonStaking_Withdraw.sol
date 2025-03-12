// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { DragonStaking_BaseTest } from "./DragonStaking_BaseTest.t.sol";
import { console } from "../../utils/console.sol";
import { math } from "../../utils/math.sol";

contract DragonStaking_Withdraw is DragonStaking_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_WhenBurnAfterWithWithdraw() external {
    vm.startPrank(DAVE);
    // Mint 604800 esP88 to Feeder
    esP88.mint(DAVE, 604800 ether);
    // Mint 302400 revenueToken to Feeder
    revenueToken.mint(DAVE, 302400 ether);
    // Mint 60480 partnerToken to Feeder
    partnerAToken.mint(DAVE, 60480 ether);

    // Mint 1000 PLP to Alice
    p88.mint(ALICE, 1000 ether);
    // Mint 1000 PLP to Bob
    p88.mint(BOB, 1000 ether);
    // Mint 1000 esP88 to Alice
    esP88.mint(ALICE, 1000 ether);
    // Mint 1000 esP88 to Bob
    esP88.mint(BOB, 1000 ether);
    // Mint 1000 dragonPoint to Alice
    dragonPoint.mint(ALICE, 1000 ether);
    // Mint 1000 dragonPoint to Bob
    dragonPoint.mint(BOB, 1000 ether);
    vm.stopPrank();

    vm.startPrank(DAVE);
    revenueToken.approve(address(revenueRewarder), type(uint256).max);
    // Feeder feed revenueToken to revenueRewarder
    // 302400 / 7 day rewardPerSec ~= 0.5 revenueToken
    revenueRewarder.feed(302400 ether, 7 days);
    vm.stopPrank();

    vm.startPrank(ALICE);
    p88.approve(address(dragonStaking), type(uint256).max);
    // Alice deposits 100 P88
    dragonStaking.deposit(ALICE, address(p88), 100 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    dragonPoint.approve(address(dragonStaking), type(uint256).max);
    // Alice deposits 100 dragonPoint
    dragonStaking.deposit(ALICE, address(dragonPoint), 100 ether);
    vm.stopPrank();

    vm.startPrank(BOB);
    p88.approve(address(dragonStaking), type(uint256).max);
    // Bob deposits 100 P88
    dragonStaking.deposit(BOB, address(p88), 100 ether);
    vm.stopPrank();

    // after 2 days
    vm.warp(block.timestamp + 2 days);

    assertEq(revenueRewarder.pendingReward(ALICE), 57600 ether);
    assertEq(revenueRewarder.pendingReward(BOB), 28800 ether);

    // 100 * 2 days / 31536000 = 0.547945205479452054
    assertEq(
      dragonPointRewarder.pendingReward(ALICE),
      0.547945205479452054 ether
    );

    {
      vm.startPrank(ALICE);
      // Alice withdraw 20 p88
      dragonStaking.withdraw(address(p88), 20 ether);
      vm.stopPrank();

      assertEq(revenueRewarder.pendingReward(ALICE), 57600 ether);
      assertEq(revenueRewarder.pendingReward(BOB), 28800 ether);
      assertEq(dragonPointRewarder.pendingReward(ALICE), 0);

      assertEq(dragonPoint.balanceOf(ALICE), 0 ether);
      assertEq(dragonStaking.userTokenAmount(address(p88), ALICE), 80 ether);
      assertEq(dragonStaking.userTokenAmount(address(esP88), ALICE), 0 ether);
      assertEq(
        dragonStaking.userTokenAmount(address(dragonPoint), ALICE),
        800.438356164383561643 ether
      ); // 80% of 100 dp + 0.547945205479452054 dp pending + 900 dp holding
    }

    // withdraw the rest
    {
      vm.startPrank(ALICE);
      // Alice withdraw 20 p88
      dragonStaking.withdraw(address(p88), 80 ether);
      vm.stopPrank();

      assertEq(dragonStaking.userTokenAmount(address(p88), ALICE), 0 ether);
      assertEq(dragonStaking.userTokenAmount(address(esP88), ALICE), 0 ether);
      assertEq(
        dragonStaking.userTokenAmount(address(dragonPoint), ALICE),
        0 ether
      );
    }

    vm.startPrank(BOB);
    // Bob withdraw 100 P88
    dragonStaking.withdraw(address(p88), 100 ether);
    vm.stopPrank();

    assertEq(dragonPointRewarder.pendingReward(BOB), 0);
  }

  function testCorrectness_WhenBurnAfterWithWithdraw_AliceWithdrawForBob()
    external
  {
    vm.startPrank(DAVE);
    // Mint 604800 esP88 to Feeder
    esP88.mint(DAVE, 604800 ether);
    // Mint 302400 revenueToken to Feeder
    revenueToken.mint(DAVE, 302400 ether);
    // Mint 60480 partnerToken to Feeder
    partnerAToken.mint(DAVE, 60480 ether);

    // Mint 1000 PLP to Alice
    p88.mint(ALICE, 1000 ether);
    // Mint 1000 PLP to Bob
    p88.mint(BOB, 1000 ether);
    // Mint 1000 esP88 to Alice
    esP88.mint(ALICE, 1000 ether);
    // Mint 1000 esP88 to Bob
    esP88.mint(BOB, 1000 ether);
    // Mint 1000 dragonPoint to Alice
    dragonPoint.mint(ALICE, 1000 ether);
    // Mint 1000 dragonPoint to Bob
    dragonPoint.mint(BOB, 1000 ether);
    vm.stopPrank();

    vm.startPrank(DAVE);
    revenueToken.approve(address(revenueRewarder), type(uint256).max);
    // Feeder feed revenueToken to revenueRewarder
    // 302400 / 7 day rewardPerSec ~= 0.5 revenueToken
    revenueRewarder.feed(302400 ether, 7 days);
    vm.stopPrank();

    vm.startPrank(ALICE);
    p88.approve(address(dragonStaking), type(uint256).max);
    // Alice deposits 100 P88
    dragonStaking.deposit(ALICE, address(p88), 100 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    dragonPoint.approve(address(dragonStaking), type(uint256).max);
    // Alice deposits 100 dragonPoint
    dragonStaking.deposit(ALICE, address(dragonPoint), 100 ether);
    vm.stopPrank();

    vm.startPrank(BOB);
    p88.approve(address(dragonStaking), type(uint256).max);
    // Bob deposits 100 P88
    dragonStaking.deposit(BOB, address(p88), 100 ether);
    vm.stopPrank();

    // after 2 days
    vm.warp(block.timestamp + 2 days);

    assertEq(revenueRewarder.pendingReward(ALICE), 57600 ether);
    assertEq(revenueRewarder.pendingReward(BOB), 28800 ether);

    // 100 * 2 days / 31536000 = 0.547945205479452054
    assertEq(
      dragonPointRewarder.pendingReward(ALICE),
      0.547945205479452054 ether
    );

    {
      vm.startPrank(ALICE);
      // Alice withdraw 20 p88
      dragonStaking.withdraw(address(p88), 20 ether);
      vm.stopPrank();

      assertEq(revenueRewarder.pendingReward(ALICE), 57600 ether);
      assertEq(revenueRewarder.pendingReward(BOB), 28800 ether);
      assertEq(dragonPointRewarder.pendingReward(ALICE), 0);

      assertEq(dragonPoint.balanceOf(ALICE), 0 ether);
      assertEq(dragonStaking.userTokenAmount(address(p88), ALICE), 80 ether);
      assertEq(dragonStaking.userTokenAmount(address(esP88), ALICE), 0 ether);
      assertEq(
        dragonStaking.userTokenAmount(address(dragonPoint), ALICE),
        800.438356164383561643 ether
      ); // 80% of 100 dp + 0.547945205479452054 dp pending + 900 dp holding
    }

    // withdraw the rest
    {
      vm.startPrank(ALICE);
      // Alice withdraw 20 p88
      dragonStaking.withdraw(address(p88), 80 ether);
      vm.stopPrank();

      assertEq(dragonStaking.userTokenAmount(address(p88), ALICE), 0 ether);
      assertEq(dragonStaking.userTokenAmount(address(esP88), ALICE), 0 ether);
      assertEq(
        dragonStaking.userTokenAmount(address(dragonPoint), ALICE),
        0 ether
      );
    }

    vm.startPrank(BOB);
    // Bob withdraw 100 P88
    dragonStaking.withdraw(address(p88), 100 ether);
    vm.stopPrank();

    assertEq(dragonPointRewarder.pendingReward(BOB), 0);
  }

  function testCorrectness_AliceShouldNotForceBobToWithdraw() external {
    vm.startPrank(DAVE);
    esP88.mint(ALICE, 80 ether);
    esP88.mint(BOB, 100 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    esP88.approve(address(dragonStaking), type(uint256).max);
    dragonStaking.deposit(ALICE, address(esP88), 80 ether);
    vm.stopPrank();

    vm.startPrank(BOB);
    esP88.approve(address(dragonStaking), type(uint256).max);
    dragonStaking.deposit(BOB, address(esP88), 100 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("DragonStaking_InsufficientTokenAmount()")
    );
    dragonStaking.withdraw(address(esP88), 100 ether);
    dragonStaking.withdraw(address(esP88), 80 ether);
    vm.stopPrank();

    assertEq(dragonStaking.userTokenAmount(address(esP88), BOB), 100 ether);
    assertEq(dragonStaking.userTokenAmount(address(esP88), ALICE), 0 ether);
  }
}
