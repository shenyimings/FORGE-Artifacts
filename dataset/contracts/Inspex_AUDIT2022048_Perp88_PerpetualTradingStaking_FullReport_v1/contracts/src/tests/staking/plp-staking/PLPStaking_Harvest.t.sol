// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { PLPStaking_BaseTest } from "./PLPStaking_BaseTest.t.sol";
import { console } from "../../utils/console.sol";
import { math } from "../../utils/math.sol";

contract PLPStaking_Harvest is PLPStaking_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_Harvest() external {
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

    {
      vm.startPrank(ALICE);
      address[] memory rewarders = new address[](3);
      rewarders[0] = address(revenueRewarder);
      rewarders[1] = address(esP88Rewarder);
      rewarders[2] = address(partnerARewarder);
      // Alice harvest
      plpStaking.harvest(rewarders);
      vm.stopPrank();
    }

    assertEq(esP88.balanceOf(ALICE), 172800 ether);
    assertEq(ALICE.balance, 86400 ether);
    assertEq(partnerAToken.balanceOf(ALICE), 17280 ether);

    assertEq(esP88Rewarder.pendingReward(ALICE), 0);
    assertEq(revenueRewarder.pendingReward(ALICE), 0);
    assertEq(partnerARewarder.pendingReward(ALICE), 0);

    vm.startPrank(ALICE);
    // Alice withdraw 100 PLP
    plpStaking.withdraw(address(plp), 100 ether);
    vm.stopPrank();

    assertEq(plp.balanceOf(ALICE), 900 ether);
    assertEq(plpStaking.userTokenAmount(address(plp), ALICE), 100 ether);
    // 3 days * 1 / 300 * 1e-6 = 0.000864
    assertEq(esP88Rewarder.accRewardPerShare(), 0.000864 ether);
    // 100 * 0.000864 * 1e6 = 86400
    assertEq(esP88Rewarder.userRewardDebts(ALICE), 86400 ether);
    // 3 days * 0.5 / 300 * 1e-6 = 0.000432
    assertEq(revenueRewarder.accRewardPerShare(), 0.000432 ether);
    // 100 * 0.000432 * 1e6 = 43200
    assertEq(revenueRewarder.userRewardDebts(ALICE), 43200 ether);
    // 3 days * 0.1 / 300 * 1e-6 = 0.0000864
    assertEq(partnerARewarder.accRewardPerShare(), 0.0000864 ether);
    // 100 * 0.0000864 * 1e6 = 8640
    assertEq(partnerARewarder.userRewardDebts(ALICE), 8640 ether);

    // after 1 days
    vm.warp(block.timestamp + 1 days);

    // 1 days * 1 * 100 / 200 = 43200
    assertEq(esP88Rewarder.pendingReward(ALICE), 43200 ether);
    // 1 days * 0.5 * 100 / 200 = 21600
    assertEq(revenueRewarder.pendingReward(ALICE), 21600 ether);
    // 1 days * 0.1 * 100 / 200 = 4320
    assertEq(partnerARewarder.pendingReward(ALICE), 4320 ether);
    // 86400 + 1 days * 1 * 100 / 200 = 129600
    assertEq(esP88Rewarder.pendingReward(BOB), 129600 ether);
    // 43200 + 1 days * 0.5 * 100 / 200 = 64800
    assertEq(revenueRewarder.pendingReward(BOB), 64800 ether);
    // 8640 + 1 days * 0.1 * 100 / 200 = 12960
    assertEq(partnerARewarder.pendingReward(BOB), 12960 ether);

    {
      vm.startPrank(BOB);
      address[] memory rewarders = new address[](1);
      rewarders[0] = address(revenueRewarder);
      // Bob harvest
      plpStaking.harvest(rewarders);
      vm.stopPrank();
    }

    assertEq(esP88.balanceOf(BOB), 0);
    assertEq(BOB.balance, 64800 ether);
    assertEq(partnerAToken.balanceOf(BOB), 0);

    assertEq(esP88Rewarder.pendingReward(BOB), 129600 ether);
    assertEq(revenueRewarder.pendingReward(BOB), 0);
    assertEq(partnerARewarder.pendingReward(BOB), 12960 ether);

    // after 5 days
    vm.warp(block.timestamp + 5 days);

    // 43200 + 3 days * 1 * 100 / 200 = 172800
    assertEq(esP88Rewarder.pendingReward(ALICE), 172800 ether);
    // 21600 + 3 days * 0.5 * 100 / 200 = 86400
    assertEq(revenueRewarder.pendingReward(ALICE), 86400 ether);
    // 4320 + 3 days * 0.1 * 100 / 200 = 17280
    assertEq(partnerARewarder.pendingReward(ALICE), 17280 ether);
    // 129600 + 3 days * 1 * 100 / 200 = 259200
    assertEq(esP88Rewarder.pendingReward(BOB), 259200 ether);
    // 3 days * 0.5 * 100 / 200 = 64800
    assertEq(revenueRewarder.pendingReward(BOB), 64800 ether);
    // 12960 + 3 days * 0.1 * 100 / 200 = 25920
    assertEq(partnerARewarder.pendingReward(BOB), 25920 ether);

    {
      vm.startPrank(ALICE);
      address[] memory rewarders = new address[](3);
      rewarders[0] = address(revenueRewarder);
      rewarders[1] = address(esP88Rewarder);
      rewarders[2] = address(partnerARewarder);
      // Alice harvest
      plpStaking.harvest(rewarders);
      vm.stopPrank();
    }

    {
      vm.startPrank(BOB);
      address[] memory rewarders = new address[](3);
      rewarders[0] = address(revenueRewarder);
      rewarders[1] = address(esP88Rewarder);
      rewarders[2] = address(partnerARewarder);
      // Bob harvest
      plpStaking.harvest(rewarders);
      vm.stopPrank();
    }
    assertEq(esP88.balanceOf(ALICE), 345600 ether);
    assertEq(ALICE.balance, 172800 ether);
    assertEq(partnerAToken.balanceOf(ALICE), 34560 ether);
    assertEq(esP88.balanceOf(BOB), 259200 ether);
    assertEq(BOB.balance, 129600 ether);
    assertEq(partnerAToken.balanceOf(BOB), 25920 ether);

    assertEq(esP88Rewarder.pendingReward(ALICE), 0);
    assertEq(revenueRewarder.pendingReward(ALICE), 0);
    assertEq(partnerARewarder.pendingReward(ALICE), 0);
    assertEq(esP88Rewarder.pendingReward(BOB), 0);
    assertEq(revenueRewarder.pendingReward(BOB), 0);
    assertEq(partnerARewarder.pendingReward(BOB), 0);
  }
}
