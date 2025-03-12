// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { Compounder_BaseTest } from "./Compounder_BaseTest.t.sol";
import { console } from "../../utils/console.sol";
import { math } from "../../utils/math.sol";

contract Compounder_Compound is Compounder_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_Compound() external {
    vm.startPrank(DAVE);
    // Mint 1814400 esP88 to Feeder
    esP88.mint(DAVE, 1814400 ether);
    // Mint 907200 revenueToken to Feeder
    revenueToken.mint(DAVE, 907200 ether);
    // Mint 60480 partnerToken to Feeder
    partnerAToken.mint(DAVE, 60480 ether);

    // Mint 1000 PLP to Alice
    plp.mint(ALICE, 1000 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    plp.approve(address(plpStaking), type(uint256).max);
    // Alice deposits 100 PLP
    plpStaking.deposit(ALICE, address(plp), 100 ether);
    vm.stopPrank();

    // after 1 hours
    vm.warp(block.timestamp + 1 hours);

    vm.startPrank(DAVE);
    // PLP Pool
    esP88.approve(address(esP88PLPPoolRewarder), type(uint256).max);
    // Feeder feed esP88 to esP88PLPPoolRewarder
    // 1209600 / 7 day rewardPerSec ~= 2 esP88
    esP88PLPPoolRewarder.feed(1209600 ether, 7 days);

    revenueToken.approve(address(revenuePLPPoolRewarder), type(uint256).max);
    // Feeder feed revenueToken to revenuePLPPoolRewarder
    // 302400 / 7 day rewardPerSec ~= 1 revenueToken
    revenuePLPPoolRewarder.feed(604800 ether, 7 days);

    // Dragon Pool
    esP88.approve(address(esP88DragonPoolRewarder), type(uint256).max);
    // Feeder feed esP88 to esP88DragonPoolRewarder
    // 604800 / 7 day rewardPerSec ~= 1 esP88
    esP88DragonPoolRewarder.feed(604800 ether, 7 days);

    revenueToken.approve(address(revenueDragonPoolRewarder), type(uint256).max);
    // Feeder feed revenueToken to revenueDragonPoolRewarder
    // 302400 / 7 day rewardPerSec ~= 0.5 revenueToken
    revenueDragonPoolRewarder.feed(302400 ether, 7 days);

    partnerAToken.approve(
      address(partnerADragonPoolRewarder),
      type(uint256).max
    );
    // Feeder feed partnerAToken to partnerADragonPoolRewarder
    // 60480 / 7 day rewardPerSec ~= 0.1 partnerAToken
    partnerADragonPoolRewarder.feed(60480 ether, 7 days);
    vm.stopPrank();

    // after 1 days
    vm.warp(block.timestamp + 1 days);

    // 1 days * 2 * 100 / 100 = 172800
    assertEq(esP88PLPPoolRewarder.pendingReward(ALICE), 172800 ether);
    // 1 days * 1 * 100 / 100 = 86400
    assertEq(revenuePLPPoolRewarder.pendingReward(ALICE), 86400 ether);
    assertEq(esP88DragonPoolRewarder.pendingReward(ALICE), 0);
    assertEq(revenueDragonPoolRewarder.pendingReward(ALICE), 0);
    assertEq(dragonPointRewarder.pendingReward(ALICE), 0);
    assertEq(partnerADragonPoolRewarder.pendingReward(ALICE), 0);

    {
      address[] memory pools = new address[](1);
      pools[0] = address(plpStaking);

      address[] memory rewarders1 = new address[](2);
      rewarders1[0] = address(esP88PLPPoolRewarder);
      rewarders1[1] = address(revenuePLPPoolRewarder);

      address[][] memory rewarders = new address[][](1);
      rewarders[0] = rewarders1;

      vm.prank(ALICE);
      // Alice compound (plpPool)
      compounder.compound(pools, rewarders);
    }

    assertEq(esP88PLPPoolRewarder.pendingReward(ALICE), 0);
    assertEq(revenuePLPPoolRewarder.pendingReward(ALICE), 0);

    assertEq(
      dragonStaking.userTokenAmount(address(esP88), ALICE),
      172800 ether
    );
    assertEq(dragonStaking.userTokenAmount(address(dragonPoint), ALICE), 0);
    assertEq(revenueToken.balanceOf(ALICE), 86400 ether);
    assertEq(partnerAToken.balanceOf(ALICE), 0);

    // after 2 days
    vm.warp(block.timestamp + 2 days);

    // 2 days * 2 * 100 / 100 = 345600
    assertEq(esP88PLPPoolRewarder.pendingReward(ALICE), 345600 ether);
    // 2 days * 1 * 100 / 100 = 172800
    assertEq(revenuePLPPoolRewarder.pendingReward(ALICE), 172800 ether);

    // 3 days * 1 * 172800 / 172800 = 259200
    assertEq(esP88DragonPoolRewarder.pendingReward(ALICE), 259200 ether);
    // 3 days * 0.5 * 172800 / 172800 = 129600
    assertEq(revenueDragonPoolRewarder.pendingReward(ALICE), 129600 ether);
    // 172800 * 2 days / 1 year = 946.849315068493150684
    assertEq(
      dragonPointRewarder.pendingReward(ALICE),
      946.849315068493150684 ether
    );
    // 3 days * 0.1 * 172800 / 172800 = 25920
    assertEq(partnerADragonPoolRewarder.pendingReward(ALICE), 25920 ether);

    {
      address[] memory pools = new address[](2);
      pools[0] = address(plpStaking);
      pools[1] = address(dragonStaking);

      address[] memory rewarders1 = new address[](2);
      rewarders1[0] = address(esP88PLPPoolRewarder);
      rewarders1[1] = address(revenuePLPPoolRewarder);
      address[] memory rewarders2 = new address[](4);
      rewarders2[0] = address(esP88DragonPoolRewarder);
      rewarders2[1] = address(revenueDragonPoolRewarder);
      rewarders2[2] = address(dragonPointRewarder);
      rewarders2[3] = address(partnerADragonPoolRewarder);

      address[][] memory rewarders = new address[][](2);
      rewarders[0] = rewarders1;
      rewarders[1] = rewarders2;

      vm.prank(ALICE);
      // Alice compound (plpPool, dragonPool)
      compounder.compound(pools, rewarders);
    }

    assertEq(esP88PLPPoolRewarder.pendingReward(ALICE), 0);
    assertEq(revenuePLPPoolRewarder.pendingReward(ALICE), 0);

    assertEq(esP88DragonPoolRewarder.pendingReward(ALICE), 0);
    assertEq(revenueDragonPoolRewarder.pendingReward(ALICE), 0);
    assertEq(dragonPointRewarder.pendingReward(ALICE), 0);
    assertEq(partnerADragonPoolRewarder.pendingReward(ALICE), 0);

    // 172800 + 345600 + 259200 = 777600
    assertEq(
      dragonStaking.userTokenAmount(address(esP88), ALICE),
      777600 ether
    );
    assertEq(
      dragonStaking.userTokenAmount(address(dragonPoint), ALICE),
      946.849315068493150684 ether
    );
    // 86400 + 172800 + 129600 = 388800
    assertEq(revenueToken.balanceOf(ALICE), 388800 ether);
    assertEq(partnerAToken.balanceOf(ALICE), 25920 ether);
  }
}
