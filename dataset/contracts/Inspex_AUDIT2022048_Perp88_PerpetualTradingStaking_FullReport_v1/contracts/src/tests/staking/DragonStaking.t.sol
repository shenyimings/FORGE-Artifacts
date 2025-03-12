// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { BaseTest } from "../base/BaseTest.sol";
import { DragonStaking } from "../../staking/DragonStaking.sol";
import { DragonPoint } from "../../tokens/DragonPoint.sol";
import { MockErc20 } from "../mocks/MockERC20.sol";
import { MockRewarder } from "../mocks/MockRewarder.sol";

contract DragonStakingTest is BaseTest {
  DragonStaking internal staking;

  MockErc20 internal p88;
  MockErc20 internal esP88;
  DragonPoint internal dp;

  MockRewarder internal prRewarder;
  MockRewarder internal esP88Rewarder;
  MockRewarder internal dpRewarder;
  MockRewarder internal pRewarder;

  function setUp() external {
    p88 = new MockErc20("P88", "P88", 18);
    esP88 = new MockErc20("esP88", "esP88", 18);
    dp = deployDragonPoint();
    dp.setMinter(address(this), true);

    prRewarder = new MockRewarder();
    esP88Rewarder = new MockRewarder();
    dpRewarder = new MockRewarder();
    pRewarder = new MockRewarder();

    address[] memory rewarders1 = new address[](4);
    rewarders1[0] = address(prRewarder);
    rewarders1[1] = address(esP88Rewarder);
    rewarders1[2] = address(dpRewarder);
    rewarders1[3] = address(pRewarder);
    address[] memory rewarders2 = new address[](2);
    rewarders2[0] = address(prRewarder);
    rewarders2[1] = address(pRewarder);

    staking = deployDragonStaking(address(dp));
    staking.addStakingToken(address(p88), rewarders1);
    staking.addStakingToken(address(esP88), rewarders1);
    staking.addStakingToken(address(dp), rewarders2);

    staking.setDragonPointRewarder(address(dpRewarder));

    dp.setMinter(address(this), true);
    dp.setMinter(address(staking), true);
    dp.setTransferrer(address(staking), true);

    p88.mint(ALICE, 1000 ether);
    p88.mint(BOB, 1000 ether);
    esP88.mint(ALICE, 1000 ether);
    esP88.mint(BOB, 1000 ether);
  }

  function testCorrectness_WhenAliceBobDeposit() external {
    dp.mint(ALICE, 1000 ether);
    dp.mint(BOB, 1000 ether);

    vm.startPrank(BOB);
    dp.approve(address(staking), 100 ether);
    staking.deposit(BOB, address(dp), 100 ether);
    vm.stopPrank();

    assertEq(dp.balanceOf(BOB), 900 ether);
    assertEq(staking.userTokenAmount(address(dp), BOB), 100 ether);

    assertEq(staking.calculateShare(address(prRewarder), BOB), 100 ether);
    assertEq(staking.calculateShare(address(esP88Rewarder), BOB), 0 ether);
    assertEq(staking.calculateShare(address(dpRewarder), BOB), 0 ether);
    assertEq(staking.calculateShare(address(pRewarder), BOB), 100 ether);

    assertEq(staking.calculateTotalShare(address(prRewarder)), 100 ether);
    assertEq(staking.calculateTotalShare(address(esP88Rewarder)), 0 ether);
    assertEq(staking.calculateTotalShare(address(dpRewarder)), 0 ether);
    assertEq(staking.calculateTotalShare(address(pRewarder)), 100 ether);

    vm.startPrank(ALICE);
    p88.approve(address(staking), 100 ether);
    staking.deposit(ALICE, address(p88), 100 ether);
    vm.stopPrank();

    assertEq(p88.balanceOf(ALICE), 900 ether);
    assertEq(staking.userTokenAmount(address(p88), ALICE), 100 ether);

    assertEq(staking.calculateShare(address(prRewarder), ALICE), 100 ether);
    assertEq(staking.calculateShare(address(esP88Rewarder), ALICE), 100 ether);
    assertEq(staking.calculateShare(address(dpRewarder), ALICE), 100 ether);
    assertEq(staking.calculateShare(address(pRewarder), ALICE), 100 ether);

    assertEq(staking.calculateTotalShare(address(prRewarder)), 200 ether);
    assertEq(staking.calculateTotalShare(address(esP88Rewarder)), 100 ether);
    assertEq(staking.calculateTotalShare(address(dpRewarder)), 100 ether);
    assertEq(staking.calculateTotalShare(address(pRewarder)), 200 ether);
  }

  function testCorrectness_WhenAliceBobWithdraw() external {
    dp.mint(ALICE, 220 ether);
    dp.mint(BOB, 150 ether);

    vm.startPrank(BOB);
    p88.approve(address(staking), 50 ether);
    esP88.approve(address(staking), 100 ether);
    dp.approve(address(staking), 150 ether);
    staking.deposit(BOB, address(p88), 50 ether);
    staking.deposit(BOB, address(esP88), 100 ether);
    staking.deposit(BOB, address(dp), 150 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    p88.approve(address(staking), 100 ether);
    dp.approve(address(staking), 100 ether);
    staking.deposit(ALICE, address(dp), 100 ether); // 120 left
    staking.deposit(ALICE, address(p88), 100 ether);
    vm.stopPrank();

    // On staking  P88   ESP88    DP
    // ALICE       100       0   100
    // BOB         50     100    150

    // Bob withdraw
    {
      assertEq(dp.balanceOf(BOB), 0 ether);
      assertEq(staking.userTokenAmount(address(p88), BOB), 50 ether);
      assertEq(staking.userTokenAmount(address(esP88), BOB), 100 ether);
      assertEq(staking.userTokenAmount(address(dp), BOB), 150 ether);

      vm.startPrank(BOB);
      esP88.approve(address(staking), 50 ether);
      staking.withdraw(address(esP88), 50 ether);
      vm.stopPrank();

      assertEq(dp.balanceOf(BOB), 0 ether);
      assertEq(staking.userTokenAmount(address(p88), BOB), 50 ether);
      assertEq(staking.userTokenAmount(address(esP88), BOB), 50 ether);
      assertEq(staking.userTokenAmount(address(dp), BOB), 100 ether);

      assertEq(staking.calculateShare(address(prRewarder), BOB), 200 ether);
      assertEq(staking.calculateShare(address(esP88Rewarder), BOB), 100 ether);
      assertEq(staking.calculateShare(address(dpRewarder), BOB), 100 ether);
      assertEq(staking.calculateShare(address(pRewarder), BOB), 200 ether);

      assertEq(staking.calculateTotalShare(address(prRewarder)), 400 ether);
      assertEq(staking.calculateTotalShare(address(esP88Rewarder)), 200 ether);
      assertEq(staking.calculateTotalShare(address(dpRewarder)), 200 ether);
      assertEq(staking.calculateTotalShare(address(pRewarder)), 400 ether);
    }

    // Alice withdraw
    {
      assertEq(dp.balanceOf(ALICE), 120 ether);
      assertEq(staking.userTokenAmount(address(p88), ALICE), 100 ether);
      assertEq(staking.userTokenAmount(address(esP88), ALICE), 0 ether);
      assertEq(staking.userTokenAmount(address(dp), ALICE), 100 ether);

      vm.startPrank(ALICE);
      p88.approve(address(staking), 50 ether);
      staking.withdraw(address(p88), 50 ether);
      vm.stopPrank();

      assertEq(dp.balanceOf(ALICE), 0 ether);
      assertEq(staking.userTokenAmount(address(p88), ALICE), 50 ether);
      assertEq(staking.userTokenAmount(address(esP88), ALICE), 0 ether);
      assertEq(staking.userTokenAmount(address(dp), ALICE), 110 ether); // 110 = (120 + 100)/2

      assertEq(staking.calculateShare(address(prRewarder), ALICE), 160 ether);
      assertEq(staking.calculateShare(address(esP88Rewarder), ALICE), 50 ether);
      assertEq(staking.calculateShare(address(dpRewarder), ALICE), 50 ether);
      assertEq(staking.calculateShare(address(pRewarder), ALICE), 160 ether);

      assertEq(staking.calculateTotalShare(address(prRewarder)), 360 ether);
      assertEq(staking.calculateTotalShare(address(esP88Rewarder)), 150 ether);
      assertEq(staking.calculateTotalShare(address(dpRewarder)), 150 ether);
      assertEq(staking.calculateTotalShare(address(pRewarder)), 360 ether);
    }

    // Alice withdraw the rest
    {
      vm.startPrank(ALICE);
      p88.approve(address(staking), 50 ether);
      staking.withdraw(address(p88), 50 ether);
      vm.stopPrank();

      assertEq(dp.balanceOf(ALICE), 0 ether);
      assertEq(staking.userTokenAmount(address(p88), ALICE), 0 ether);
      assertEq(staking.userTokenAmount(address(esP88), ALICE), 0 ether);
      assertEq(staking.userTokenAmount(address(dp), ALICE), 0 ether); // 110 = (120 + 100)/2

      assertEq(staking.calculateShare(address(prRewarder), ALICE), 0 ether);
      assertEq(staking.calculateShare(address(esP88Rewarder), ALICE), 0 ether);
      assertEq(staking.calculateShare(address(dpRewarder), ALICE), 0 ether);
      assertEq(staking.calculateShare(address(pRewarder), ALICE), 0 ether);

      assertEq(staking.calculateTotalShare(address(prRewarder)), 200 ether);
      assertEq(staking.calculateTotalShare(address(esP88Rewarder)), 100 ether);
      assertEq(staking.calculateTotalShare(address(dpRewarder)), 100 ether);
      assertEq(staking.calculateTotalShare(address(pRewarder)), 200 ether);
    }
  }

  function testRevert_WhenAliceWithdrawDragonPoint() external {
    vm.startPrank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("DragonStaking_DragonPointWithdrawForbid()")
    );
    staking.withdraw(address(dp), 50 ether);
    vm.stopPrank();
  }

  function testRevert_WhenAliceWithdraw0Token() external {
    vm.startPrank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("DragonStaking_InvalidTokenAmount()")
    );
    staking.withdraw(address(p88), 0 ether);
    vm.stopPrank();
  }
}
