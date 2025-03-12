// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { DragonStaking_BaseTest } from "./DragonStaking_BaseTest.t.sol";
import { console } from "../../utils/console.sol";
import { math } from "../../utils/math.sol";

contract DragonStaking_Deposit is DragonStaking_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_Deposit() external {
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

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    vm.startPrank(ALICE);
    p88.approve(address(dragonStaking), type(uint256).max);
    // Alice deposits 100 P88
    dragonStaking.deposit(ALICE, address(p88), 100 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    esP88.approve(address(dragonStaking), type(uint256).max);
    // Alice deposits 100 esP88
    dragonStaking.deposit(ALICE, address(esP88), 100 ether);
    vm.stopPrank();

    assertEq(p88.balanceOf(ALICE), 900 ether);
    assertEq(esP88.balanceOf(ALICE), 900 ether);
    assertEq(dragonStaking.userTokenAmount(address(p88), ALICE), 100 ether);
    assertEq(dragonStaking.userTokenAmount(address(esP88), ALICE), 100 ether);

    assertEq(esP88Rewarder.pendingReward(ALICE), 0);
    assertEq(esP88Rewarder.accRewardPerShare(), 0);
    assertEq(esP88Rewarder.userRewardDebts(ALICE), 0);
    assertEq(revenueRewarder.pendingReward(ALICE), 0);
    assertEq(revenueRewarder.accRewardPerShare(), 0);
    assertEq(revenueRewarder.userRewardDebts(ALICE), 0);
    assertEq(partnerARewarder.pendingReward(ALICE), 0);
    assertEq(partnerARewarder.accRewardPerShare(), 0);
    assertEq(partnerARewarder.userRewardDebts(ALICE), 0);
    assertEq(dragonPointRewarder.pendingReward(ALICE), 0);
    assertEq(dragonPointRewarder.userLastRewards(ALICE), 3601);
    assertEq(dragonPointRewarder.userAccRewards(ALICE), 0);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // 200 * 3600 / 31536000 = 0.022831050228310502
    assertEq(
      dragonPointRewarder.pendingReward(ALICE),
      0.022831050228310502 ether
    );

    vm.startPrank(BOB);
    p88.approve(address(dragonStaking), type(uint256).max);
    // Bob deposits 50 P88
    dragonStaking.deposit(BOB, address(p88), 50 ether);
    vm.stopPrank();

    vm.startPrank(BOB);
    esP88.approve(address(dragonStaking), type(uint256).max);
    // Bob deposits 50 esP88
    dragonStaking.deposit(BOB, address(esP88), 50 ether);
    vm.stopPrank();

    assertEq(p88.balanceOf(BOB), 950 ether);
    assertEq(esP88.balanceOf(BOB), 950 ether);
    assertEq(dragonStaking.userTokenAmount(address(p88), BOB), 50 ether);
    assertEq(dragonStaking.userTokenAmount(address(esP88), BOB), 50 ether);

    assertEq(esP88Rewarder.pendingReward(BOB), 0);
    assertEq(esP88Rewarder.accRewardPerShare(), 0);
    assertEq(esP88Rewarder.userRewardDebts(BOB), 0);
    assertEq(revenueRewarder.pendingReward(BOB), 0);
    assertEq(revenueRewarder.accRewardPerShare(), 0);
    assertEq(revenueRewarder.userRewardDebts(BOB), 0);
    assertEq(partnerARewarder.pendingReward(BOB), 0);
    assertEq(partnerARewarder.accRewardPerShare(), 0);
    assertEq(partnerARewarder.userRewardDebts(BOB), 0);
    assertEq(dragonPointRewarder.pendingReward(BOB), 0);
    assertEq(dragonPointRewarder.userLastRewards(BOB), 7201);
    assertEq(dragonPointRewarder.userAccRewards(BOB), 0);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // 200 * 7200 / 31536000 = 0.045662100456621004
    assertEq(
      dragonPointRewarder.pendingReward(ALICE),
      0.045662100456621004 ether
    );
    // 100 * 3600 / 31536000 = 0.011415525114155251
    assertEq(
      dragonPointRewarder.pendingReward(BOB),
      0.011415525114155251 ether
    );

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

    // 3 days * 1 * 100 / 150 = 172800
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

    // 200 * 266400 / 31536000 = 1.689497716894977168
    assertEq(
      dragonPointRewarder.pendingReward(ALICE),
      1.689497716894977168 ether
    );
    // 100 * 262800 / 31536000 = 0.833333333333333333
    assertEq(
      dragonPointRewarder.pendingReward(BOB),
      0.833333333333333333 ether
    );

    vm.startPrank(BOB);
    p88.approve(address(dragonStaking), type(uint256).max);
    // Bob deposits 50 P88
    dragonStaking.deposit(BOB, address(p88), 50 ether);
    vm.stopPrank();

    vm.startPrank(BOB);
    esP88.approve(address(dragonStaking), type(uint256).max);
    // Bob deposits 50 esP88
    dragonStaking.deposit(BOB, address(esP88), 50 ether);
    vm.stopPrank();

    assertEq(p88.balanceOf(BOB), 900 ether);
    assertEq(esP88.balanceOf(BOB), 900 ether);
    assertEq(dragonStaking.userTokenAmount(address(p88), BOB), 100 ether);
    assertEq(dragonStaking.userTokenAmount(address(esP88), BOB), 100 ether);

    // 3 days * 1 / 300 * 1e-6 = 0.000864
    assertEq(esP88Rewarder.accRewardPerShare(), 0.000864 ether);
    // 100 * 0.000864 * 1e6 = 86400
    assertEq(esP88Rewarder.userRewardDebts(BOB), 86400 ether);
    // 3 days * 0.5 / 300 * 1e-6 = 0.000432
    assertEq(revenueRewarder.accRewardPerShare(), 0.000432 ether);
    // 100 * 0.000432 * 1e6 = 43200
    assertEq(revenueRewarder.userRewardDebts(BOB), 43200 ether);
    // 3 days * 0.1 / 300 * 1e-6 = 0.0000864
    assertEq(partnerARewarder.accRewardPerShare(), 0.0000864 ether);
    // 100 * 0.0000864 * 1e6 = 8640
    assertEq(partnerARewarder.userRewardDebts(BOB), 8640 ether);

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

    // 200 * 266400 / 31536000 = 1.689497716894977168
    assertEq(
      dragonPointRewarder.pendingReward(ALICE),
      1.689497716894977168 ether
    );
    // 100 * 262800 / 31536000 = 0.833333333333333333
    assertEq(
      dragonPointRewarder.pendingReward(BOB),
      0.833333333333333333 ether
    );

    // after 3 days
    vm.warp(block.timestamp + 3 days);

    // 172800 + 3 days * 1 * 200 / 400 = 302400
    assertEq(esP88Rewarder.pendingReward(ALICE), 302400 ether);
    // 86400 + 3 days * 0.5 * 200 / 400 = 151200
    assertEq(revenueRewarder.pendingReward(ALICE), 151200 ether);
    // 17280 + 3 days * 0.1 * 200 / 400 = 30240
    assertEq(partnerARewarder.pendingReward(ALICE), 30240 ether);
    // 86400 + 3 days * 1 * 200 / 400 = 216000
    assertEq(esP88Rewarder.pendingReward(BOB), 216000 ether);
    // 43200 + 3 days * 0.5 * 200 / 400 = 108000
    assertEq(revenueRewarder.pendingReward(BOB), 108000 ether);
    // 8640 + 3 days * 0.1 * 200 / 400 = 21600
    assertEq(partnerARewarder.pendingReward(BOB), 21600 ether);

    vm.startPrank(ALICE);
    dragonPoint.approve(address(dragonStaking), type(uint256).max);
    // Alice deposits 100 dragonPoint
    dragonStaking.deposit(ALICE, address(dragonPoint), 100 ether);
    vm.stopPrank();

    assertEq(dragonPoint.balanceOf(ALICE), 900 ether);
    assertEq(
      dragonStaking.userTokenAmount(address(dragonPoint), ALICE),
      100 ether
    );

    vm.startPrank(BOB);
    dragonPoint.approve(address(dragonStaking), type(uint256).max);
    // Bob deposits 50 dragonPoint
    dragonStaking.deposit(BOB, address(dragonPoint), 50 ether);
    vm.stopPrank();

    assertEq(dragonPoint.balanceOf(BOB), 950 ether);
    assertEq(
      dragonStaking.userTokenAmount(address(dragonPoint), BOB),
      50 ether
    );

    // after 3 days
    vm.warp(block.timestamp + 3 days);

    // 172800 + 4 days * 1 * 200 / 400 = 345600
    assertEq(esP88Rewarder.pendingReward(ALICE), 345600 ether);
    // 151200 + 1 days * 0.5 * 300 / 550 = 174763.636363636363636363
    math.almostEqual(
      revenueRewarder.pendingReward(ALICE),
      174763.636363636363636363 ether,
      1
    );
    // 30240 + 1 days * 0.1 * 300 / 550 = 34952.727272727272727272
    math.almostEqual(
      partnerARewarder.pendingReward(ALICE),
      34952.727272727272727272 ether,
      1
    );
    // 86400 + 4 days * 1 * 200 / 400 = 259200
    assertEq(esP88Rewarder.pendingReward(BOB), 259200 ether);
    // 108000 + 1 days * 0.5 * 250 / 550 = 127636.363636363636363636
    math.almostEqual(
      revenueRewarder.pendingReward(BOB),
      127636.363636363636363636 ether,
      1
    );
    // 21600 + 1 days * 0.1 * 200 / 400 = 25527.272727272727272727
    math.almostEqual(
      partnerARewarder.pendingReward(BOB),
      25527.272727272727272727 ether,
      1
    );

    // 200 * 784800 / 31536000 = 4.977168949771689497
    assertEq(
      dragonPointRewarder.pendingReward(ALICE),
      4.977168949771689497 ether
    );
    // 0.833333333333333333 + 200 * 518400 / 31536000 = 4.121004566210045661
    assertEq(
      dragonPointRewarder.pendingReward(BOB),
      4.121004566210045661 ether
    );
  }
}
