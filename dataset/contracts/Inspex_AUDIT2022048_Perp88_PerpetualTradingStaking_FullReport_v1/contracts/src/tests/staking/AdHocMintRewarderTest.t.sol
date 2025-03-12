// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { BaseTest } from "../base/BaseTest.sol";
import { AdHocMintRewarder } from "../../staking/AdHocMintRewarder.sol";
import { MockErc20 } from "../mocks/MockERC20.sol";
import { MockSimpleStaking } from "../mocks/MockSimpleStaking.sol";
import { console } from "../utils/console.sol";
import { math } from "../utils/math.sol";

contract AdHocMintRewarderTest is BaseTest {
  AdHocMintRewarder internal rewarder;
  MockErc20 internal rewardToken;
  MockSimpleStaking internal mockStaking;

  function setUp() external {
    mockStaking = new MockSimpleStaking();

    rewardToken = new MockErc20("DragonPoint Token", "DP", 18);
    rewarder = deployAdHocMintRewarder(
      "DPRewarder",
      address(rewardToken),
      address(mockStaking)
    );
  }

  function testCorrectness_WhenRewarderIsInit() external {
    assertEq(rewarder.name(), "DPRewarder");
    assertEq(rewarder.rewardToken(), address(rewardToken));
  }

  function testRevert_WhenHookIsCalled_BySomeRandomGuy() external {
    vm.startPrank(ALICE);

    vm.expectRevert(
      abi.encodeWithSignature("AdHocMintRewarderError_NotStakingContract()")
    );
    rewarder.onDeposit(BOB, 1 ether);

    vm.expectRevert(
      abi.encodeWithSignature("AdHocMintRewarderError_NotStakingContract()")
    );
    rewarder.onWithdraw(BOB, 1 ether);

    vm.expectRevert(
      abi.encodeWithSignature("AdHocMintRewarderError_NotStakingContract()")
    );
    rewarder.onHarvest(BOB, CAT);

    vm.stopPrank();
  }

  function testCorrectness_WhenDepositMulitpleTimes_AndHarvestMultipleTimes(
    uint256 depositAmount1,
    uint256 depositAmount2,
    uint256 depositAmount3,
    uint256 depositAmount4
  ) external {
    vm.assume(depositAmount1 < 1e12 ether);
    vm.assume(depositAmount2 < 1e12 ether);
    vm.assume(depositAmount3 < 1e12 ether);
    vm.assume(depositAmount4 < 1e12 ether);

    uint256 accReward = 0;
    uint256 totalDeposit = 0;
    // DAY#0
    // ALICE deposit
    // time has not pass
    mockStaking.deposit(address(rewarder), ALICE, depositAmount1);

    accReward += 0;
    totalDeposit += depositAmount1;
    assertEq(rewarder.userLastRewards(ALICE), block.timestamp);
    assertEq(rewarder.userAccRewards(ALICE), accReward);

    // DAY#30
    // ALICE deposit again
    vm.warp(block.timestamp + 30 days);
    mockStaking.deposit(address(rewarder), ALICE, depositAmount2);

    accReward += (totalDeposit * 30 days) / 365 days;
    totalDeposit += depositAmount2;
    assertEq(rewarder.userLastRewards(ALICE), block.timestamp);
    assertEq(rewarder.userAccRewards(ALICE), accReward);
    // assertTrue(math.almostEqual(rewarder.userAccRewards(ALICE), accReward1, 1));

    // DAY#90
    // ALICE deposit again
    vm.warp(block.timestamp + 60 days);
    mockStaking.deposit(address(rewarder), ALICE, depositAmount3);

    accReward += (totalDeposit * 60 days) / 365 days;
    totalDeposit += depositAmount3;
    assertEq(rewarder.userLastRewards(ALICE), block.timestamp);
    assertEq(rewarder.userAccRewards(ALICE), accReward);

    // DAY#455
    // ALICE wants to harvest, a year later
    vm.warp(block.timestamp + 365 days);
    assertEq(rewardToken.balanceOf(ALICE), 0);
    mockStaking.harvest(address(rewarder), ALICE);
    accReward += (totalDeposit * 365 days) / 365 days;
    assertEq(rewarder.userLastRewards(ALICE), block.timestamp);
    assertEq(rewardToken.balanceOf(ALICE), accReward);
    accReward = 0;

    // DAY#460
    // ALICE deposit again
    vm.warp(block.timestamp + 5 days);
    mockStaking.deposit(address(rewarder), ALICE, depositAmount4);

    accReward += (totalDeposit * 5 days) / 365 days;
    totalDeposit += depositAmount4;
    assertEq(rewarder.userLastRewards(ALICE), block.timestamp);
    assertEq(rewarder.userAccRewards(ALICE), accReward);

    // DAY#478
    // ALICE wants to harvest
    vm.warp(block.timestamp + 18 days);
    {
      uint256 balanceBefore = rewardToken.balanceOf(ALICE);
      mockStaking.harvest(address(rewarder), ALICE);
      uint256 balanceAfter = rewardToken.balanceOf(ALICE);

      accReward += (totalDeposit * 18 days) / 365 days;
      assertEq(rewarder.userLastRewards(ALICE), block.timestamp);
      assertEq(balanceAfter - balanceBefore, accReward);
    }
  }

  function testCorrectness_WhenDeposit_ThenWithdraw_ThenDepositAgain(
    uint256 depositAmount1,
    uint256 withdrawAmount,
    uint256 depositAmount2
  ) external {
    vm.assume(depositAmount1 < 1e12 ether);
    vm.assume(depositAmount1 >= withdrawAmount);
    vm.assume(depositAmount2 < 1e12 ether);

    uint256 accReward = 0;
    uint256 totalDeposit = 0;
    // DAY#0
    // ALICE deposit
    // time has not pass
    mockStaking.deposit(address(rewarder), ALICE, depositAmount1);

    accReward += 0;
    totalDeposit += depositAmount1;
    assertEq(rewarder.userLastRewards(ALICE), block.timestamp);
    assertEq(rewarder.userAccRewards(ALICE), accReward);

    // DAY#40
    // ALICE withdraw
    vm.warp(block.timestamp + 40 days);
    mockStaking.withdraw(address(rewarder), ALICE, withdrawAmount);

    accReward = 0;
    totalDeposit -= withdrawAmount;
    assertEq(rewarder.userLastRewards(ALICE), block.timestamp);
    assertEq(rewarder.userAccRewards(ALICE), accReward);

    // DAY#145
    // ALICE check pending
    vm.warp(block.timestamp + 105 days);
    assertEq(rewarder.userLastRewards(ALICE), block.timestamp - 105 days);
    assertEq(
      rewarder.pendingReward(ALICE),
      (totalDeposit * 105 days) / 365 days
    );

    // DAY#220
    // ALICE deposit again
    vm.warp(block.timestamp + 75 days);
    mockStaking.deposit(address(rewarder), ALICE, depositAmount2);

    accReward += (totalDeposit * 180 days) / 365 days;
    totalDeposit += depositAmount2;
    assertEq(rewarder.userLastRewards(ALICE), block.timestamp);
    assertEq(rewarder.userAccRewards(ALICE), accReward);

    // DAY#238
    // ALICE wants to harvest
    vm.warp(block.timestamp + 18 days);

    assertEq(rewardToken.balanceOf(ALICE), 0);
    mockStaking.harvest(address(rewarder), ALICE);
    accReward += (totalDeposit * 18 days) / 365 days;
    assertEq(rewarder.userLastRewards(ALICE), block.timestamp);
    assertEq(rewardToken.balanceOf(ALICE), accReward);
  }
}
