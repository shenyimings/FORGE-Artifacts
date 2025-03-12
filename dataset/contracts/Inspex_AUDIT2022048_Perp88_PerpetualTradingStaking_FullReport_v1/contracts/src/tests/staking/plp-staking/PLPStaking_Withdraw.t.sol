// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { PLPStaking_BaseTest } from "./PLPStaking_BaseTest.t.sol";
import { console } from "../../utils/console.sol";
import { math } from "../../utils/math.sol";

contract PLPStaking_Withdraw is PLPStaking_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_WhenWithdrawNotDistributeReward() external {
    vm.prank(DAVE);
    // Mint 1000 PLP to Alice
    plp.mint(ALICE, 1000 ether);

    vm.startPrank(ALICE);
    plp.approve(address(plpStaking), type(uint256).max);
    // Alice deposits 100 PLP
    plpStaking.deposit(ALICE, address(plp), 100 ether);
    vm.stopPrank();

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    vm.startPrank(ALICE);
    plp.approve(address(plpStaking), type(uint256).max);
    // Alice withdraw 30 PLP
    plpStaking.withdraw(address(plp), 30 ether);
    vm.stopPrank();

    assertEq(plp.balanceOf(ALICE), 930 ether);
    assertEq(plpStaking.userTokenAmount(address(plp), ALICE), 70 ether);
    assertEq(revenueRewarder.accRewardPerShare(), 0);
    assertEq(revenueRewarder.userRewardDebts(ALICE), 0);
    assertEq(esP88Rewarder.accRewardPerShare(), 0);
    assertEq(esP88Rewarder.userRewardDebts(ALICE), 0);
    assertEq(partnerARewarder.accRewardPerShare(), 0);
    assertEq(partnerARewarder.userRewardDebts(ALICE), 0);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    vm.startPrank(ALICE);
    plp.approve(address(plpStaking), type(uint256).max);
    // Alice withdraw 70 PLP
    plpStaking.withdraw(address(plp), 70 ether);
    vm.stopPrank();

    assertEq(plp.balanceOf(ALICE), 1000 ether);
    assertEq(plpStaking.userTokenAmount(address(plp), ALICE), 0);
    assertEq(revenueRewarder.accRewardPerShare(), 0);
    assertEq(revenueRewarder.userRewardDebts(ALICE), 0);
    assertEq(esP88Rewarder.accRewardPerShare(), 0);
    assertEq(esP88Rewarder.userRewardDebts(ALICE), 0);
    assertEq(partnerARewarder.accRewardPerShare(), 0);
    assertEq(partnerARewarder.userRewardDebts(ALICE), 0);
  }

  function testCorrectness_WhenRewardOffBeforeWithdraw() external {
    vm.startPrank(DAVE);
    // Mint 604800 esP88 to Feeder
    esP88.mint(DAVE, 604800 ether);
    // Mint 1000 PLP to Alice
    plp.mint(ALICE, 1000 ether);
    // Mint 1000 PLP to Bob
    plp.mint(BOB, 1000 ether);
    vm.stopPrank();

    vm.startPrank(DAVE);
    esP88.approve(address(esP88Rewarder), type(uint256).max);
    // Feeder feed esP88 to esP88Rewarder
    // 604800 / 7 day rewardPerSec ~= 1 esP88
    esP88Rewarder.feed(604800 ether, 7 days);
    vm.stopPrank();

    // after 8 days
    vm.warp(block.timestamp + 8 days);

    vm.startPrank(ALICE);
    plp.approve(address(plpStaking), type(uint256).max);
    // Alice deposits 100 PLP
    plpStaking.deposit(ALICE, address(plp), 100 ether);
    vm.stopPrank();

    assertEq(esP88Rewarder.accRewardPerShare(), 0);
    assertEq(esP88Rewarder.userRewardDebts(ALICE), 0);
    assertEq(esP88Rewarder.lastRewardTime(), 1);
    assertEq(esP88Rewarder.pendingReward(ALICE), 604800 ether);

    vm.startPrank(ALICE);
    // Alice withdraw 100 PLP
    plpStaking.withdraw(address(plp), 100 ether);
    vm.stopPrank();

    // 604800 * 1 / 100 * 1e-6 = 0.006048
    assertEq(esP88Rewarder.accRewardPerShare(), 0.006048 ether);
    // 100 * 0.006048 * 1e6 = 604800
    assertEq(esP88Rewarder.userRewardDebts(ALICE), -604800 ether);
    // 8 days
    assertEq(esP88Rewarder.lastRewardTime(), 691201);
    assertEq(esP88Rewarder.pendingReward(ALICE), 604800 ether);
  }

  function testCorrectness_WhenWithdrawUtilRewardOffStillWithdraw() external {
    vm.startPrank(DAVE);
    // Mint 604800 esP88 to Feeder
    esP88.mint(DAVE, 604800 ether);
    // Mint 1000 PLP to Alice
    plp.mint(ALICE, 1000 ether);
    // Mint 1000 PLP to Bob
    plp.mint(BOB, 1000 ether);
    vm.stopPrank();

    vm.startPrank(DAVE);
    esP88.approve(address(esP88Rewarder), type(uint256).max);
    // Feeder feed esP88 to esP88Rewarder
    // 604800 / 7 day rewardPerSec ~= 1 esP88
    esP88Rewarder.feed(604800 ether, 7 days);
    vm.stopPrank();

    vm.startPrank(ALICE);
    plp.approve(address(plpStaking), type(uint256).max);
    // Alice deposits 100 PLP
    plpStaking.deposit(ALICE, address(plp), 100 ether);
    vm.stopPrank();

    // 4 days * 1 / 100 * 1e-6 = 0.003456
    assertEq(esP88Rewarder.accRewardPerShare(), 0);
    // 100 * 0.003456 * 1e6 = 345600
    assertEq(esP88Rewarder.userRewardDebts(ALICE), 0);
    // 4 days
    assertEq(esP88Rewarder.lastRewardTime(), 1);

    // after 4 days
    vm.warp(block.timestamp + 4 days);

    vm.startPrank(ALICE);
    // Alice withdraw 30 PLP
    plpStaking.withdraw(address(plp), 30 ether);
    vm.stopPrank();

    // 4 days * 1 / 100 * 1e-6 = 0.003456
    assertEq(esP88Rewarder.accRewardPerShare(), 0.003456 ether);
    // 30 * 0.003456 * 1e6 = 103680
    assertEq(esP88Rewarder.userRewardDebts(ALICE), -103680 ether);
    // 4 days
    assertEq(esP88Rewarder.lastRewardTime(), 345601);

    // after 4 days
    vm.warp(block.timestamp + 4 days);

    // 7 days * 1 * 100 / 100 ~= 604800 || 604799999999999940000000
    math.almostEqual(esP88Rewarder.pendingReward(ALICE), 604800 ether, 1);

    vm.startPrank(ALICE);
    // Bob withdraw 70 PLP
    plpStaking.withdraw(address(plp), 70 ether);
    vm.stopPrank();

    // 0.003456 + 3 days * 1 / 70 * 1e-6 = 0.007158857142857142
    assertEq(esP88Rewarder.accRewardPerShare(), 0.007158857142857142 ether);
    // 103680 + 70 * 0.007158857142857142 * 1e6 = 604799.99999999994
    assertEq(esP88Rewarder.userRewardDebts(ALICE), -604799.99999999994 ether);
    // 8 days
    assertEq(esP88Rewarder.lastRewardTime(), 691201);
  }

  function testCorrectness_Withdraw() external {
    vm.startPrank(DAVE);
    // Mint 604800 esP88 to Feeder
    esP88.mint(DAVE, 604800 ether);
    // Mint 302400 revenueToken to Feeder
    vm.deal(DAVE, 302400 ether);
    revenueToken.deposit{ value: 302400 ether }();
    // Mint 60480 partnerToken to Feeder
    partnerAToken.mint(DAVE, 60480 ether);
    // Mint 1000 PLP to Alice
    plp.mint(ALICE, 1000 ether);
    // Mint 1000 PLP to Bob
    plp.mint(BOB, 1000 ether);
    vm.stopPrank();

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    vm.startPrank(ALICE);
    plp.approve(address(plpStaking), type(uint256).max);
    // Alice deposits 200 PLP
    plpStaking.deposit(ALICE, address(plp), 200 ether);
    vm.stopPrank();

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    vm.startPrank(BOB);
    plp.approve(address(plpStaking), type(uint256).max);
    // Bob deposits 100 PLP
    plpStaking.deposit(BOB, address(plp), 100 ether);
    vm.stopPrank();

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    vm.startPrank(DAVE);
    esP88.approve(address(esP88Rewarder), type(uint256).max);
    // Feeder feed esP88 to esP88Rewarder
    // 604800 / 7 day rewardPerSec ~= 1 esP88
    esP88Rewarder.feed(604800 ether, 7 days);

    revenueToken.approve(address(revenueRewarder), type(uint256).max);
    // Feeder feed revenueToken to revenueRewarder
    // 302400 / 7 day rewardPerSec ~= 0.5 revenueToken
    revenueRewarder.feed(302400 ether, 7 days);

    partnerAToken.approve(address(partnerARewarder), type(uint256).max);
    // Feeder feed partnerAToken to partnerARewarder
    // 60480 / 7 day rewardPerSec ~= 0.1 partnerAToken
    partnerARewarder.feed(60480 ether, 7 days);
    vm.stopPrank();

    // after 3 days
    vm.warp(block.timestamp + 3 days);

    // 3 days * 1 * 200 / 300 = 172800
    assertEq(esP88Rewarder.pendingReward(ALICE), 172800 ether);
    // 3 days * 0.5 * 200 / 300 = 86400
    assertEq(revenueRewarder.pendingReward(ALICE), 86400 ether);
    // 3 days * 0.1 * 200 / 300 = 17280
    assertEq(partnerARewarder.pendingReward(ALICE), 17280 ether);
    // 3 days * 1 * 100 / 300 = 86400
    assertEq(esP88Rewarder.pendingReward(BOB), 86400 ether);
    // 3 days * 0.5 * 100 / 300 = 43200
    assertEq(revenueRewarder.pendingReward(BOB), 43200 ether);
    // 3 days * 0.1 * 100 / 300 = 8640
    assertEq(partnerARewarder.pendingReward(BOB), 8640 ether);

    vm.startPrank(ALICE);
    // Alice withdraw 100 PLP
    plpStaking.withdraw(address(plp), 100 ether);
    vm.stopPrank();

    assertEq(plp.balanceOf(ALICE), 900 ether);
    assertEq(plpStaking.userTokenAmount(address(plp), ALICE), 100 ether);
    // 259200
    // 3 days * 1 / 300 * 1e-6 = 0.000864
    assertEq(esP88Rewarder.accRewardPerShare(), 0.000864 ether);
    // 100 * 0.000864 * 1e6 = 86400
    assertEq(esP88Rewarder.userRewardDebts(ALICE), -86400 ether);
    // 3 days 3 hours
    assertEq(esP88Rewarder.lastRewardTime(), 270001);
    // 3 days * 0.5 / 300 * 1e-6 = 0.000432
    assertEq(revenueRewarder.accRewardPerShare(), 0.000432 ether);
    // 100 * 0.000432 * 1e6 = 43200
    assertEq(revenueRewarder.userRewardDebts(ALICE), -43200 ether);
    // 3 days 3 hours
    assertEq(revenueRewarder.lastRewardTime(), 270001);
    // 3 days * 0.1 / 300 * 1e-6 = 0.0000864
    assertEq(partnerARewarder.accRewardPerShare(), 0.0000864 ether);
    // 100 * 0.0000864 * 1e6 = 8640
    assertEq(partnerARewarder.userRewardDebts(ALICE), -8640 ether);
    // 3 days 3 hours
    assertEq(partnerARewarder.lastRewardTime(), 270001);

    // 3 days * 1 * 100 / 300 = 172800
    assertEq(esP88Rewarder.pendingReward(ALICE), 172800 ether);
    // 3 days * 0.5 * 100 / 150 = 86400
    assertEq(revenueRewarder.pendingReward(ALICE), 86400 ether);
    // 3 days * 0.1 * 100 / 150 = 17280
    assertEq(partnerARewarder.pendingReward(ALICE), 17280 ether);
    // 3 days * 1 * 50 / 150 = 86400
    assertEq(esP88Rewarder.pendingReward(BOB), 86400 ether);
    // 3 days * 0.5 * 50 / 150 = 43200
    assertEq(revenueRewarder.pendingReward(BOB), 43200 ether);
    // 3 days * 0.1 * 50 / 150 = 8640
    assertEq(partnerARewarder.pendingReward(BOB), 8640 ether);

    // after 5 days
    vm.warp(block.timestamp + 5 days);

    // 172800 + 4 days * 1 * 100 / 200 = 345600
    assertEq(esP88Rewarder.pendingReward(ALICE), 345600 ether);
    // 86400 + 4 days * 0.5 * 100 / 200 = 172800
    assertEq(revenueRewarder.pendingReward(ALICE), 172800 ether);
    // 17280 + 4 days * 0.1 * 100 / 200 = 34560
    assertEq(partnerARewarder.pendingReward(ALICE), 34560 ether);
    // 86400 + 4 days * 1 * 100 / 200 = 259200
    assertEq(esP88Rewarder.pendingReward(BOB), 259200 ether);
    // 43200 + 4 days * 0.5 * 100 / 200 = 129600
    assertEq(revenueRewarder.pendingReward(BOB), 129600 ether);
    // 8640 + 4 days * 0.1 * 100 / 200 = 25920
    assertEq(partnerARewarder.pendingReward(BOB), 25920 ether);

    vm.startPrank(ALICE);
    // Alice withdraw 100 PLP
    plpStaking.withdraw(address(plp), 100 ether);
    vm.stopPrank();

    assertEq(plp.balanceOf(ALICE), 1000 ether);
    assertEq(plpStaking.userTokenAmount(address(plp), ALICE), 0 ether);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    vm.startPrank(BOB);
    // Bob withdraw 100 PLP
    plpStaking.withdraw(address(plp), 100 ether);
    vm.stopPrank();

    assertEq(plp.balanceOf(BOB), 1000 ether);
    assertEq(plpStaking.userTokenAmount(address(plp), BOB), 0 ether);

    assertEq(esP88Rewarder.pendingReward(ALICE), 345600 ether);
    assertEq(revenueRewarder.pendingReward(ALICE), 172800 ether);
    assertEq(partnerARewarder.pendingReward(ALICE), 34560 ether);
    assertEq(esP88Rewarder.pendingReward(BOB), 259200 ether);
    assertEq(revenueRewarder.pendingReward(BOB), 129600 ether);
    assertEq(partnerARewarder.pendingReward(BOB), 25920 ether);
  }

  function testCorrectness_AliceShouldNotForceBobToWithdraw() external {
    vm.startPrank(DAVE);
    plp.mint(ALICE, 80 ether);
    plp.mint(BOB, 100 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    plp.approve(address(plpStaking), type(uint256).max);
    plpStaking.deposit(ALICE, address(plp), 80 ether);
    vm.stopPrank();

    vm.startPrank(BOB);
    plp.approve(address(plpStaking), type(uint256).max);
    plpStaking.deposit(BOB, address(plp), 100 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("PLPStaking_InsufficientTokenAmount()")
    );
    plpStaking.withdraw(address(plp), 100 ether);
    plpStaking.withdraw(address(plp), 80 ether);
    vm.stopPrank();

    assertEq(plpStaking.userTokenAmount(address(plp), BOB), 100 ether);
    assertEq(plpStaking.userTokenAmount(address(plp), ALICE), 0 ether);
  }
}
