// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { PLPStaking_BaseTest } from "./PLPStaking_BaseTest.t.sol";
import { console } from "../../utils/console.sol";

contract PLPStaking_Deposit is PLPStaking_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_WhenDepositNotDistributeReward() external {
    vm.prank(DAVE);
    // Mint 1000 PLP to Alice
    plp.mint(ALICE, 1000 ether);

    vm.startPrank(ALICE);
    plp.approve(address(plpStaking), type(uint256).max);
    // Alice deposits 100 PLP
    plpStaking.deposit(ALICE, address(plp), 100 ether);
    vm.stopPrank();

    assertEq(plp.balanceOf(ALICE), 900 ether);
    assertEq(plpStaking.userTokenAmount(address(plp), ALICE), 100 ether);
    assertEq(revenueRewarder.accRewardPerShare(), 0);
    assertEq(revenueRewarder.userRewardDebts(ALICE), 0);
    assertEq(esP88Rewarder.accRewardPerShare(), 0);
    assertEq(esP88Rewarder.userRewardDebts(ALICE), 0);
    assertEq(partnerARewarder.accRewardPerShare(), 0);
    assertEq(partnerARewarder.userRewardDebts(ALICE), 0);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    vm.startPrank(ALICE);
    // Alice deposit 100 PLP
    plpStaking.deposit(ALICE, address(plp), 100 ether);
    vm.stopPrank();

    assertEq(plp.balanceOf(ALICE), 800 ether);
    assertEq(plpStaking.userTokenAmount(address(plp), ALICE), 200 ether);
    assertEq(revenueRewarder.accRewardPerShare(), 0);
    assertEq(revenueRewarder.userRewardDebts(ALICE), 0);
    assertEq(esP88Rewarder.accRewardPerShare(), 0);
    assertEq(esP88Rewarder.userRewardDebts(ALICE), 0);
    assertEq(partnerARewarder.accRewardPerShare(), 0);
    assertEq(partnerARewarder.userRewardDebts(ALICE), 0);
  }

  function testCorrectness_WhenFeedRewardAfterDeposit() external {
    vm.startPrank(DAVE);
    // Mint 604800 esP88 to Feeder
    esP88.mint(DAVE, 604800 ether);
    // Mint 1000 PLP to Alice
    plp.mint(ALICE, 1000 ether);
    // Mint 1000 PLP to Bob
    plp.mint(BOB, 1000 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    plp.approve(address(plpStaking), type(uint256).max);
    // Alice deposits 100 PLP
    plpStaking.deposit(ALICE, address(plp), 100 ether);
    vm.stopPrank();

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    vm.startPrank(DAVE);
    esP88.approve(address(esP88Rewarder), type(uint256).max);
    // Feeder feed esP88 to esP88Rewarder
    // 604800 / 7 day rewardPerSec ~= 1 esP88
    esP88Rewarder.feed(604800 ether, 7 days);
    vm.stopPrank();

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // 1 hours * 1 * 100 / 100 = 3600
    assertEq(esP88Rewarder.pendingReward(ALICE), 3600 ether);

    vm.startPrank(BOB);
    plp.approve(address(plpStaking), type(uint256).max);
    // Bob deposits 100 PLP
    plpStaking.deposit(BOB, address(plp), 100 ether);
    vm.stopPrank();

    // 3600 * 1 / 100 * 1e-6 = 0.000036
    assertEq(esP88Rewarder.accRewardPerShare(), 0.000036 ether);
    // 100 * 0.000036 * 1e6 = 3600
    assertEq(esP88Rewarder.userRewardDebts(BOB), 3600 ether);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // 3600 + (1 hours * 1 * 100 / 200) = 5400
    assertEq(esP88Rewarder.pendingReward(ALICE), 5400 ether);
    // 1 hours * 1 * 100 / 200 = 1800
    assertEq(esP88Rewarder.pendingReward(BOB), 1800 ether);
  }

  function testCorrectness_WhenAddRewarderAferDeposit() external {
    vm.startPrank(DAVE);
    // Mint 604800 PB to Feeder
    partnerBToken.mint(DAVE, 604800 ether);
    // Mint 1000 PLP to Alice
    plp.mint(ALICE, 1000 ether);
    // Mint 1000 PLP to Bob
    plp.mint(BOB, 1000 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    plp.approve(address(plpStaking), type(uint256).max);
    // Alice deposits 100 PLP
    plpStaking.deposit(ALICE, address(plp), 100 ether);
    vm.stopPrank();

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    vm.startPrank(DAVE);
    // Add Partner B Rewarder
    address[] memory tokens = new address[](1);
    tokens[0] = address(plp);
    plpStaking.addRewarder(address(partnerBRewarder), tokens);
    partnerBToken.approve(address(partnerBRewarder), type(uint256).max);
    // Feeder feed PB to partnerBRewarder
    // 604800 / 7 day rewardPerSec ~= 1 PB
    partnerBRewarder.feed(604800 ether, 7 days);
    vm.stopPrank();

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // 1 hours * 1 * 100 / 100 = 3600
    assertEq(partnerBRewarder.pendingReward(ALICE), 3600 ether);

    vm.startPrank(BOB);
    plp.approve(address(plpStaking), type(uint256).max);
    // Bob deposits 100 PLP
    plpStaking.deposit(BOB, address(plp), 100 ether);
    vm.stopPrank();

    // 3600 * 1 / 100 * 1e-6 = 0.000036
    assertEq(partnerBRewarder.accRewardPerShare(), 0.000036 ether);
    // 100 * 0.000036 * 1e6 = 3600
    assertEq(partnerBRewarder.userRewardDebts(BOB), 3600 ether);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    // 3600 + (1 hours * 1 * 100 / 200) = 5400
    assertEq(partnerBRewarder.pendingReward(ALICE), 5400 ether);
    // 1 hours * 1 * 100 / 200 = 1800
    assertEq(partnerBRewarder.pendingReward(BOB), 1800 ether);
  }

  function testCorrectness_WhenRewardOffBeforeDeposit() external {
    vm.startPrank(DAVE);
    // Mint 604800 esP88 to Feeder
    esP88.mint(DAVE, 604800 ether);
    // Mint 1000 PLP to Alice
    plp.mint(ALICE, 1000 ether);
    // Mint 1000 PLP to Bob
    plp.mint(BOB, 1000 ether);
    vm.stopPrank();

    vm.warp(block.timestamp + 8 days);

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
    assertEq(esP88Rewarder.lastRewardTime(), 691201);
    assertEq(esP88Rewarder.pendingReward(ALICE), 604800 ether);

    vm.startPrank(BOB);
    plp.approve(address(plpStaking), type(uint256).max);
    // Bob deposits 100 PLP
    plpStaking.deposit(BOB, address(plp), 100 ether);
    vm.stopPrank();

    // 7 days * 1 / 100 * 1e-6 = 0.00604800
    assertEq(esP88Rewarder.accRewardPerShare(), 0.00604800 ether);
    assertEq(esP88Rewarder.userRewardDebts(BOB), 604800 ether);
    // 8 days
    assertEq(esP88Rewarder.lastRewardTime(), 1382401);
    assertEq(esP88Rewarder.pendingReward(BOB), 0);
  }

  function testCorrectness_WhenDepositUtilRewardOffStillDeposit() external {
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

    // after 4 days
    vm.warp(block.timestamp + 4 days);

    vm.startPrank(ALICE);
    plp.approve(address(plpStaking), type(uint256).max);
    // Alice deposits 100 PLP
    plpStaking.deposit(ALICE, address(plp), 100 ether);
    vm.stopPrank();

    assertEq(esP88Rewarder.accRewardPerShare(), 0);
    assertEq(esP88Rewarder.userRewardDebts(ALICE), 0);
    assertEq(esP88Rewarder.lastRewardTime(), 1);

    // after 8 days
    vm.warp(block.timestamp + 8 days);

    // 7 days * 1 * 100 / 100 = 604800
    assertEq(esP88Rewarder.pendingReward(ALICE), 604800 ether);

    vm.startPrank(BOB);
    plp.approve(address(plpStaking), type(uint256).max);
    // Bob deposits 100 PLP
    plpStaking.deposit(BOB, address(plp), 100 ether);
    vm.stopPrank();

    assertEq(esP88Rewarder.pendingReward(BOB), 0);
    // 7 days * 1 / 100 * 1e-6 = 0.00604800
    assertEq(esP88Rewarder.accRewardPerShare(), 0.00604800 ether);
    // 100 * 0.00604800 * 1e6 = 604800
    assertEq(esP88Rewarder.userRewardDebts(BOB), 604800 ether);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    vm.prank(ALICE);
    // Alice deposits 100 PLP
    plpStaking.deposit(ALICE, address(plp), 100 ether);

    assertEq(esP88Rewarder.pendingReward(ALICE), 604800 ether);
    // 7 days * 1 / 100 * 1e-6 = 0.00604800
    assertEq(esP88Rewarder.accRewardPerShare(), 0.00604800 ether);
    // 100 * 0.00604800 * 1e6 = 604800
    assertEq(esP88Rewarder.userRewardDebts(ALICE), 604800 ether);
  }

  function testCorrectness_Deposit() external {
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
    // Alice deposits 100 PLP
    plpStaking.deposit(ALICE, address(plp), 100 ether);
    vm.stopPrank();

    assertEq(plp.balanceOf(ALICE), 900 ether);
    assertEq(plpStaking.userTokenAmount(address(plp), ALICE), 100 ether);
    assertEq(esP88Rewarder.pendingReward(ALICE), 0);
    assertEq(esP88Rewarder.accRewardPerShare(), 0);
    assertEq(esP88Rewarder.userRewardDebts(ALICE), 0);
    assertEq(esP88Rewarder.lastRewardTime(), 1);
    assertEq(revenueRewarder.pendingReward(ALICE), 0);
    assertEq(revenueRewarder.accRewardPerShare(), 0);
    assertEq(revenueRewarder.userRewardDebts(ALICE), 0);
    assertEq(revenueRewarder.lastRewardTime(), 1);
    assertEq(partnerARewarder.pendingReward(ALICE), 0);
    assertEq(partnerARewarder.accRewardPerShare(), 0);
    assertEq(partnerARewarder.userRewardDebts(ALICE), 0);
    assertEq(partnerARewarder.lastRewardTime(), 1);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    vm.startPrank(BOB);
    plp.approve(address(plpStaking), type(uint256).max);
    // Bob deposits 100 PLP
    plpStaking.deposit(BOB, address(plp), 50 ether);
    vm.stopPrank();

    assertEq(plp.balanceOf(BOB), 950 ether);
    assertEq(plpStaking.userTokenAmount(address(plp), BOB), 50 ether);
    assertEq(esP88Rewarder.pendingReward(BOB), 0);
    assertEq(esP88Rewarder.accRewardPerShare(), 0);
    assertEq(esP88Rewarder.userRewardDebts(BOB), 0);
    // 2 hours
    assertEq(esP88Rewarder.lastRewardTime(), 7201);
    assertEq(revenueRewarder.pendingReward(BOB), 0);
    assertEq(revenueRewarder.accRewardPerShare(), 0);
    assertEq(revenueRewarder.userRewardDebts(BOB), 0);
    // 2 hours
    assertEq(revenueRewarder.lastRewardTime(), 7201);
    assertEq(partnerARewarder.pendingReward(BOB), 0);
    assertEq(partnerARewarder.accRewardPerShare(), 0);
    assertEq(partnerARewarder.userRewardDebts(BOB), 0);
    // 2 hours
    assertEq(partnerARewarder.lastRewardTime(), 7201);

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

    // 3 hours
    assertEq(esP88Rewarder.lastRewardTime(), 10801);
    // 3 hours
    assertEq(revenueRewarder.lastRewardTime(), 10801);
    // 3 hours
    assertEq(partnerARewarder.lastRewardTime(), 10801);

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

    vm.startPrank(BOB);
    // Alice deposits 100 PLP
    plpStaking.deposit(BOB, address(plp), 50 ether);
    vm.stopPrank();

    assertEq(plp.balanceOf(BOB), 900 ether);
    assertEq(plpStaking.userTokenAmount(address(plp), BOB), 100 ether);
    // 3 days * 1 / 150 * 1e-6 = 0.001728
    assertEq(esP88Rewarder.accRewardPerShare(), 0.001728 ether);
    // 50 * 0.001728 * 1e6 = 86400
    assertEq(esP88Rewarder.userRewardDebts(BOB), 86400 ether);
    // 3 days 3 hours
    assertEq(esP88Rewarder.lastRewardTime(), 270001);
    // 3 days * 0.5 / 150 * 1e-6 = 0.000864
    assertEq(revenueRewarder.accRewardPerShare(), 0.000864 ether);
    // 50 * 0.000864 * 1e6 = 43200
    assertEq(revenueRewarder.userRewardDebts(BOB), 43200 ether);
    // 3 days 3 hours
    assertEq(revenueRewarder.lastRewardTime(), 270001);
    // 3 days * 0.1 / 150 * 1e-6 = 0.0001728
    assertEq(partnerARewarder.accRewardPerShare(), 0.0001728 ether);
    // 50 * 0.0001728 * 1e6 = 8640
    assertEq(partnerARewarder.userRewardDebts(BOB), 8640 ether);
    // 3 days 3 hours
    assertEq(partnerARewarder.lastRewardTime(), 270001);

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
    // Alice deposits 100 PLP
    plpStaking.deposit(ALICE, address(plp), 100 ether);
    vm.stopPrank();

    assertEq(plp.balanceOf(ALICE), 800 ether);
    assertEq(plpStaking.userTokenAmount(address(plp), ALICE), 200 ether);

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    vm.startPrank(BOB);
    // Bob deposits 100 PLP
    plpStaking.deposit(BOB, address(plp), 100 ether);
    vm.stopPrank();

    assertEq(plp.balanceOf(BOB), 800 ether);
    assertEq(plpStaking.userTokenAmount(address(plp), BOB), 200 ether);

    assertEq(esP88Rewarder.pendingReward(ALICE), 345600 ether);
    assertEq(revenueRewarder.pendingReward(ALICE), 172800 ether);
    assertEq(partnerARewarder.pendingReward(ALICE), 34560 ether);
    assertEq(esP88Rewarder.pendingReward(BOB), 259200 ether);
    assertEq(revenueRewarder.pendingReward(BOB), 129600 ether);
    assertEq(partnerARewarder.pendingReward(BOB), 25920 ether);
  }
}
