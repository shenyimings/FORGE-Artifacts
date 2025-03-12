// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { BaseTest } from "../base/BaseTest.sol";
import { PLPStaking } from "../../staking/PLPStaking.sol";
import { MockErc20 } from "../mocks/MockERC20.sol";
import { MockRewarder } from "../mocks/MockRewarder.sol";

contract PLPStakingTest is BaseTest {
  PLPStaking internal staking;

  MockErc20 internal plp;
  MockErc20 internal p168;

  MockRewarder internal protocolRevenueRewarder;
  MockRewarder internal esP88Rewarder;
  MockRewarder internal partnerRewarder;

  function setUp() external {
    plp = new MockErc20("PLP", "PLP", 18);
    p168 = new MockErc20("P168", "P168", 18);

    protocolRevenueRewarder = new MockRewarder();
    esP88Rewarder = new MockRewarder();
    partnerRewarder = new MockRewarder();

    address[] memory rewarders1 = new address[](3);
    rewarders1[0] = address(protocolRevenueRewarder);
    rewarders1[1] = address(esP88Rewarder);
    rewarders1[2] = address(partnerRewarder);

    staking = deployPLPStaking();
    staking.addStakingToken(address(plp), rewarders1);

    plp.mint(ALICE, 100 ether);
    plp.mint(BOB, 100 ether);
    p168.mint(BOB, 100 ether);
  }

  function testRevert_NotStakingToken_WhenAliceDeposit() external {
    vm.expectRevert(
      abi.encodeWithSignature("PLPStaking_UnknownStakingToken()")
    );
    vm.prank(ALICE);
    staking.deposit(ALICE, address(p168), 100 ether);
  }

  function testRevert_InsufficientAllowance_WhenAliceDeposit() external {
    vm.startPrank(ALICE);
    vm.expectRevert("ERC20: insufficient allowance");
    staking.deposit(ALICE, address(plp), 100 ether);
    vm.stopPrank();
  }

  function testRevert_InsufficientBalance_WhenAliceDeposit() external {
    vm.startPrank(ALICE);
    plp.approve(address(staking), 200 ether);
    vm.expectRevert("ERC20: transfer amount exceeds balance");
    staking.deposit(ALICE, address(plp), 200 ether);
    vm.stopPrank();
  }

  function testCorrectness_WhenAliceBobDeposit() external {
    vm.startPrank(BOB);
    plp.approve(address(staking), 100 ether);
    staking.deposit(BOB, address(plp), 100 ether);
    vm.stopPrank();

    assertEq(plp.balanceOf(BOB), 0);
    assertEq(staking.userTokenAmount(address(plp), BOB), 100 ether);

    assertEq(
      staking.calculateShare(address(protocolRevenueRewarder), BOB),
      100 ether
    );
    assertEq(staking.calculateShare(address(esP88Rewarder), BOB), 100 ether);
    assertEq(staking.calculateShare(address(partnerRewarder), BOB), 100 ether);

    assertEq(
      staking.calculateTotalShare(address(protocolRevenueRewarder)),
      100 ether
    );
    assertEq(staking.calculateTotalShare(address(esP88Rewarder)), 100 ether);
    assertEq(staking.calculateTotalShare(address(partnerRewarder)), 100 ether);

    vm.startPrank(ALICE);
    plp.approve(address(staking), 100 ether);
    staking.deposit(ALICE, address(plp), 100 ether);
    vm.stopPrank();

    assertEq(plp.balanceOf(ALICE), 0);
    assertEq(staking.userTokenAmount(address(plp), ALICE), 100 ether);

    assertEq(
      staking.calculateShare(address(protocolRevenueRewarder), ALICE),
      100 ether
    );
    assertEq(staking.calculateShare(address(esP88Rewarder), ALICE), 100 ether);
    assertEq(
      staking.calculateShare(address(partnerRewarder), ALICE),
      100 ether
    );

    assertEq(
      staking.calculateTotalShare(address(protocolRevenueRewarder)),
      200 ether
    );
    assertEq(staking.calculateTotalShare(address(esP88Rewarder)), 200 ether);
    assertEq(staking.calculateTotalShare(address(partnerRewarder)), 200 ether);
  }

  function testRevert_NotStakingToken_WhenAliceWithdraw() external {
    vm.startPrank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("PLPStaking_UnknownStakingToken()")
    );
    staking.withdraw(address(p168), 100 ether);
    vm.stopPrank();
  }

  function testRevert_InsufficientBalance_WhenAliceWithdraw() external {
    vm.startPrank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("PLPStaking_InsufficientTokenAmount()")
    );
    staking.withdraw(address(plp), 100 ether);
    vm.stopPrank();
  }

  function testCorrectness_WhenAliceBobWithdraw() external {
    vm.startPrank(BOB);
    plp.approve(address(staking), 100 ether);
    staking.deposit(BOB, address(plp), 100 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    plp.approve(address(staking), 100 ether);
    staking.deposit(ALICE, address(plp), 100 ether);
    vm.stopPrank();

    vm.prank(BOB);
    staking.withdraw(address(plp), 50 ether);

    assertEq(plp.balanceOf(BOB), 50 ether);
    assertEq(staking.userTokenAmount(address(plp), BOB), 50 ether);

    assertEq(
      staking.calculateShare(address(protocolRevenueRewarder), BOB),
      50 ether
    );
    assertEq(staking.calculateShare(address(esP88Rewarder), BOB), 50 ether);
    assertEq(staking.calculateShare(address(partnerRewarder), BOB), 50 ether);

    assertEq(
      staking.calculateTotalShare(address(protocolRevenueRewarder)),
      150 ether
    );
    assertEq(staking.calculateTotalShare(address(esP88Rewarder)), 150 ether);
    assertEq(staking.calculateTotalShare(address(partnerRewarder)), 150 ether);

    vm.prank(ALICE);
    staking.withdraw(address(plp), 100 ether);

    assertEq(plp.balanceOf(ALICE), 100 ether);
    assertEq(staking.userTokenAmount(address(plp), ALICE), 0 ether);

    assertEq(
      staking.calculateShare(address(protocolRevenueRewarder), ALICE),
      0 ether
    );
    assertEq(staking.calculateShare(address(esP88Rewarder), ALICE), 0 ether);
    assertEq(staking.calculateShare(address(partnerRewarder), ALICE), 0 ether);

    assertEq(
      staking.calculateTotalShare(address(protocolRevenueRewarder)),
      50 ether
    );
    assertEq(staking.calculateTotalShare(address(esP88Rewarder)), 50 ether);
    assertEq(staking.calculateTotalShare(address(partnerRewarder)), 50 ether);
  }

  function testCorrectness_WhenAddStakingTokenRewarder() external {
    vm.startPrank(BOB);
    plp.approve(address(staking), 100 ether);
    staking.deposit(BOB, address(plp), 100 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    plp.approve(address(staking), 100 ether);
    staking.deposit(ALICE, address(plp), 100 ether);
    vm.stopPrank();

    address[] memory rewarders = new address[](3);
    rewarders[0] = address(protocolRevenueRewarder);
    rewarders[1] = address(esP88Rewarder);
    rewarders[2] = address(partnerRewarder);
    staking.addStakingToken(address(p168), rewarders);

    vm.startPrank(BOB);
    p168.approve(address(staking), 100 ether);
    staking.deposit(BOB, address(p168), 100 ether);
    vm.stopPrank();

    assertEq(plp.balanceOf(BOB), 0);
    assertEq(staking.userTokenAmount(address(p168), BOB), 100 ether);

    assertEq(
      staking.calculateShare(address(protocolRevenueRewarder), BOB),
      200 ether
    );
    assertEq(staking.calculateShare(address(esP88Rewarder), BOB), 200 ether);
    assertEq(staking.calculateShare(address(partnerRewarder), BOB), 200 ether);

    assertEq(
      staking.calculateShare(address(protocolRevenueRewarder), ALICE),
      100 ether
    );
    assertEq(staking.calculateShare(address(esP88Rewarder), ALICE), 100 ether);
    assertEq(
      staking.calculateShare(address(partnerRewarder), ALICE),
      100 ether
    );

    assertEq(
      staking.calculateTotalShare(address(protocolRevenueRewarder)),
      300 ether
    );
    assertEq(staking.calculateTotalShare(address(esP88Rewarder)), 300 ether);
    assertEq(staking.calculateTotalShare(address(partnerRewarder)), 300 ether);
  }

  function testCorrectness_WhenAddPartnerRewarder() external {
    MockRewarder P2Rewarder = new MockRewarder();
    address[] memory tokens = new address[](1);
    tokens[0] = address(plp);

    vm.startPrank(BOB);
    plp.approve(address(staking), 100 ether);
    staking.deposit(BOB, address(plp), 100 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    plp.approve(address(staking), 100 ether);
    staking.deposit(ALICE, address(plp), 100 ether);
    vm.stopPrank();

    staking.addRewarder(address(P2Rewarder), tokens);

    assertEq(staking.calculateShare(address(P2Rewarder), ALICE), 100 ether);
    assertEq(staking.calculateShare(address(P2Rewarder), BOB), 100 ether);

    assertEq(staking.calculateTotalShare(address(P2Rewarder)), 200 ether);
  }

  function testCorreness_WhenHarvest_WithValidRewarders() external {
    address[] memory rewarders = new address[](4);
    rewarders[0] = address(protocolRevenueRewarder);
    rewarders[1] = address(esP88Rewarder);
    rewarders[2] = address(partnerRewarder);
    rewarders[3] = address(partnerRewarder); // with duplicate rewarder, should be ok too

    vm.startPrank(ALICE);
    staking.harvest(rewarders);
    vm.stopPrank();
  }

  function testRevert_WhenHarvest_WithInvalidRewarders() external {
    address[] memory rewarders = new address[](1);
    rewarders[0] = address(88); // some random address

    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("PLPStaking_NotRewarder()"));
    staking.harvest(rewarders);
    vm.stopPrank();
  }

  function testCorreness_WhenHarvestToCompounder_WithValidRewarders() external {
    address[] memory rewarders = new address[](4);
    rewarders[0] = address(protocolRevenueRewarder);
    rewarders[1] = address(esP88Rewarder);
    rewarders[2] = address(partnerRewarder);
    rewarders[3] = address(partnerRewarder); // with duplicate rewarder, should be ok too

    address compounder = address(99);
    staking.setCompounder(compounder);

    vm.startPrank(compounder);
    staking.harvestToCompounder(ALICE, rewarders);
    vm.stopPrank();
  }

  function testRevert_WhenHarvestToCompounder_BySomeRandomAccount() external {
    address[] memory rewarders = new address[](0);
    address compounder = address(99);
    staking.setCompounder(compounder);

    vm.startPrank(BOB);
    vm.expectRevert(abi.encodeWithSignature("PLPStaking_NotCompounder()"));
    staking.harvestToCompounder(ALICE, rewarders);
    vm.stopPrank();
  }
}
