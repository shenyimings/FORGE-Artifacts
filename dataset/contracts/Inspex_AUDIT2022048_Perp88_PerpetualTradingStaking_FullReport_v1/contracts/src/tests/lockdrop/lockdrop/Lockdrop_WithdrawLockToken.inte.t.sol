// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Lockdrop_BaseTest, console } from "./Lockdrop_BaseTest.inte.t.sol";

contract Lockdrop_WithdrawLockToken is Lockdrop_BaseTest {
  uint256 lockAmount;
  uint256 lockPeriod;

  function setUp() public override {
    super.setUp();
    usdcPriceFeed.setLatestAnswer(1 * 10**8);

    lockAmount = 16 ether;
    lockPeriod = 8 days;

    vm.startPrank(ALICE);
    usdc.mint(ALICE, 20 ether);
    usdc.approve(address(lockdrop), 20 ether);
    vm.stopPrank();
  }

  // Early withdraw within restricted withdrawal time which is 3 day after start lock time
  function testCorrectness_WhenUserLockToken_ThenEarlyWithdrawSomeAmount_WithinFirst3Days()
    external
  {
    vm.startPrank(ALICE);
    // 3 hours after start lock time
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);

    // Alice Lock 16 USDC for 8 days
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      ,
      bool aliceWithdrawOnce
    ) = lockdrop.lockdropStates(ALICE);

    // Withdraw timestamp
    // 1 day after ALICE lock token.
    // ALICE need to with draw 5 USDC
    vm.warp(lockdropConfig.startLockTimestamp() + 1 days);
    assertTrue(!aliceWithdrawOnce);
    lockdrop.earlyWithdrawLockedToken(5 ether, ALICE);

    (alicelockdropTokenAmount, alicelockPeriod, , aliceWithdrawOnce) = lockdrop
      .lockdropStates(ALICE);
    vm.stopPrank();

    // After Alice withdraw the USDC token from the first 3 days, the following criteria needs to satisfy:
    // 1. Balance of Alice's USDC token should be 9
    // 2. The amount of Alice's lockdrop token should be 11
    // 3. The number of lock period should be 8 days
    // 4. The total amount of lock token should be 11
    // 5. The total weight of P88 should be 11 * 8 days
    // 6. Alice restrictedWithdrawn state should remain false

    assertEq(usdc.balanceOf(ALICE), 9 ether);
    assertEq(alicelockdropTokenAmount, 11 ether);
    assertEq(alicelockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), 11 ether);
    assertEq(lockdrop.totalP88Weight(), 11 ether * lockPeriod);
    assertTrue(!aliceWithdrawOnce);
  }

  // Early withdraw within restricted withdrawal time which is 3 day after start lock time
  function testCorrectness_WhenUserLockToken_ThenEarlyWithdrawAllAmount_WithinFirst3Days()
    external
  {
    vm.startPrank(ALICE);
    // 3 hour after lock time start
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);

    // Alice Lock 16 USDC for 8 days
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      ,
      bool aliceWithdrawOnce
    ) = lockdrop.lockdropStates(ALICE);

    // Withdraw timestamp
    // 1 day after ALICE lock token.
    // ALICE need to with draw all lock USDC
    vm.warp(lockdropConfig.startLockTimestamp() + 1 days);
    lockdrop.earlyWithdrawLockedToken(lockAmount, ALICE);
    (alicelockdropTokenAmount, alicelockPeriod, , aliceWithdrawOnce) = lockdrop
      .lockdropStates(ALICE);

    vm.stopPrank();
    // After Alice withdraw the USDC token from the first 3 days, the following criteria needs to satisfy:
    // 1. Balance of Alice's USDC token should be 20
    // 2. The amount of Alice's lockdrop token should be 0
    // 3. The number of lock period should be 0
    // 4. The total amount of lock token should be 0
    // 5. The total weight of P88 should be 0
    // 6 Alice restrictedWithdrawn should remain false
    assertEq(usdc.balanceOf(ALICE), 20 ether);
    assertEq(alicelockdropTokenAmount, 0);
    assertEq(alicelockPeriod, 0);
    assertEq(lockdrop.totalAmount(), 0);
    assertEq(lockdrop.totalP88Weight(), 0);
    assertTrue(!aliceWithdrawOnce);
  }

  // Early withdraw within restricted withdrawal time which is 3 day after start lock time
  function testCorrectness_WhenUserLockToken_ThenEarlyWithdrawSomeAmountMultipleTime_WithinFirst3Days()
    external
  {
    vm.startPrank(ALICE);
    // 3 hour after lock time start
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);

    // Alice Lock 16 USDC for 8 days
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      bool aliceP88Claimed,
      bool aliceWithdrawOnce
    ) = lockdrop.lockdropStates(ALICE);

    // Withdraw timestamp
    // 1 day after ALICE lock token.
    // ALICE need to with draw 2 times

    vm.warp(lockdropConfig.startLockTimestamp() + 1 days);
    lockdrop.earlyWithdrawLockedToken(5 ether, ALICE);
    (alicelockdropTokenAmount, alicelockPeriod, , aliceWithdrawOnce) = lockdrop
      .lockdropStates(ALICE);

    // After Alice withdraw the USDC token within the first 3 days, the following criteria needs to satisfy:
    // 1. Balance of Alice's USDC token should be 9
    // 2. The amount of Alice's lockdrop token should be 11
    // 3. The number of lock period should be 8 days
    // 4. The total amount of lock token should be 11
    // 5. The total weight of P88 should be 11 * 8 days
    // 6. Alice restrictedWithdrawn should remain false

    assertEq(usdc.balanceOf(ALICE), 9 ether);
    assertEq(alicelockdropTokenAmount, 11 ether);
    assertEq(alicelockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), 11 ether);
    assertEq(lockdrop.totalP88Weight(), 11 ether * lockPeriod);
    assertTrue(!aliceWithdrawOnce);

    vm.warp(lockdropConfig.startLockTimestamp() + 2 days);
    lockdrop.earlyWithdrawLockedToken(11 ether, ALICE);
    (alicelockdropTokenAmount, alicelockPeriod, , aliceWithdrawOnce) = lockdrop
      .lockdropStates(ALICE);
    vm.stopPrank();

    // After Alice withdraw all of her USDC token within the first 3 days, the following criteria needs to satisfy:
    // 1. Balance of Alice's USDC token should be 20
    // 2. Alice is now deleted from lockdropStates so her lock token amount is 0
    // 3. Alice is now deleted from lockdropStates so her lock period is 0
    // 4. Alice restrictedWithdrawn should remain false

    assertEq(usdc.balanceOf(ALICE), 20 ether);
    assertEq(alicelockdropTokenAmount, 0);
    assertEq(alicelockPeriod, 0);
    assertTrue(!aliceWithdrawOnce);
  }

  // Early withdraw after restricted withdrawal time but within decaying with time which is first 12 hour
  // User cannot early withdraw more than half of lock token amount
  function testCorrectness_LockdropEarlyWithdrawLockToken_WithdrawDay4First12Hours()
    external
  {
    vm.startPrank(ALICE);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      ,
      bool aliceWihdrawOnce
    ) = lockdrop.lockdropStates(ALICE);

    // Withdraw timestamp
    vm.warp(lockdropConfig.startLockTimestamp() + 3 days + 2 hours);
    assertEq(lockdrop.getEarlyWithdrawableAmount(ALICE), 8 ether);
    assertTrue(!aliceWihdrawOnce);
    lockdrop.earlyWithdrawLockedToken(5 ether, ALICE);
    (alicelockdropTokenAmount, alicelockPeriod, , aliceWihdrawOnce) = lockdrop
      .lockdropStates(ALICE);

    vm.stopPrank();

    // After Alice withdraw the USDC token on day 4 in the first 12 hours, the following criteria needs to satisfy:
    // 1. Balance of Alice's USDC token should be 9
    // 2. The amount of Alice's lockdrop token should be 11
    // 3. The number of lock period should be 8 days
    // 4. The total amount of lock token should be 11
    // 5. The total weight of P88 should be 11 * 8 days
    // 6. Alice restrictedWithdrawn state should be set to true

    assertEq(usdc.balanceOf(ALICE), 9 ether);
    assertEq(alicelockdropTokenAmount, 11 ether);
    assertEq(alicelockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), 11 ether);
    assertEq(lockdrop.totalP88Weight(), 11 ether * lockPeriod);
    assertTrue(aliceWihdrawOnce);
  }

  // Early withdraw after restricted withdrawal time and after decaying withdraw time
  // but still in lockdrop period which is last 12 hour of day 4
  // User cannot early withdraw more than the ratio of remaining time
  function testCorrectness_LockdropEarlyWithdrawLockToken_WithdrawDay4Last12Hours()
    external
  {
    vm.startPrank(ALICE);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      bool aliceP88Claimed,
      bool aliceWihdrawOnce
    ) = lockdrop.lockdropStates(ALICE);

    assertTrue(!aliceWihdrawOnce);
    // Withdraw timestamp: Day 4 after 12 hours
    vm.warp(lockdropConfig.startLockTimestamp() + 3 days + 18 hours);
    assertEq(lockdrop.getEarlyWithdrawableAmount(ALICE), 4 ether);

    lockdrop.earlyWithdrawLockedToken(4 ether, ALICE);
    (
      alicelockdropTokenAmount,
      alicelockPeriod,
      aliceP88Claimed,
      aliceWihdrawOnce
    ) = lockdrop.lockdropStates(ALICE);
    vm.stopPrank();

    // After Alice withdraw the USDC token on day 4 in the last 12 hours, the following criteria needs to satisfy:
    // 1. Balance of Alice's USDC token should be 8
    // 2. The amount of Alice's lockdrop token should be 12
    // 3. Alice hasn't claim her P88 so should be false
    // 4. The number of lock period should be 8 days
    // 5. The total amount of lock token should be 12
    // 6. The total weight of P88 should be 12 * 8 days
    // 7. Alice restrictedWithdrawn state should be set to true

    assertEq(usdc.balanceOf(ALICE), 8 ether);
    assertEq(alicelockdropTokenAmount, 12 ether);
    assertEq(alicelockPeriod, lockPeriod);
    assertTrue(!aliceP88Claimed);
    assertEq(lockdrop.totalAmount(), 12 ether);
    assertEq(lockdrop.totalP88Weight(), 12 ether * lockPeriod);
    assertTrue(aliceWihdrawOnce);
  }

  function testRevert_LockdropEarlyWithdrawLockToken_ExceedLockdropPeriod()
    external
  {
    vm.startPrank(ALICE);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    lockdrop.lockToken(lockAmount, lockPeriod);

    // After Alice withdraw the USDC token after lockdrop period, the following criteria needs to satisfy:
    // 1. expect revert Lockdrop_NotInLockdropPeriod()

    vm.warp(lockdropConfig.startLockTimestamp() + 4 days + 1 hours);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_NotInLockdropPeriod()"));
    lockdrop.earlyWithdrawLockedToken(5 ether, ALICE);
    vm.stopPrank();
  }

  // Early withdraw after restricted withdrawal time but within decaying withdraw time which is first 12 hour
  // User cannot early withdraw more than half of lock token amount
  function testRevert_LockdropEarlyWithdrawLockToken_WithdrawDay4First12HoursInvalidAmount()
    external
  {
    vm.startPrank(ALICE);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);

    lockdrop.lockToken(lockAmount, lockPeriod);

    // After Alice withdraw the USDC token within decaying withdraw but more than 50% , the following criteria needs to satisfy:
    // 1. expect revert Lockdrop_InvalidAmount()

    // Withdraw timestamp
    vm.warp(lockdropConfig.startLockTimestamp() + 3 days + 2 hours);
    // ALICE need to Withdraw more than 50%
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_InvalidAmount()"));
    lockdrop.earlyWithdrawLockedToken(10 ether, ALICE);
    vm.stopPrank();
  }

  // Early withdraw after restricted withdrawal time and after decaying withdraw time
  // but still in lockdrop period which is last 12 hour of day 4
  // User cannot early withdraw more than the ratio of remaining time
  function testRevert_LockdropEarlyWithdrawLockToken_WithdrawDay4Last12HoursInvalidAmount()
    external
  {
    vm.startPrank(ALICE);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);

    lockdrop.lockToken(lockAmount, lockPeriod);

    // After Alice withdraw the USDC token after decaying withdraw but more than valid ratio amount , the following criteria needs to satisfy:
    // 1. expect revert Lockdrop_InvalidAmount()

    // Withdraw timestamp: Day 4 after 12 hours
    vm.warp(lockdropConfig.startLockTimestamp() + 3 days + 18 hours);
    // Withdraw more than valid amount
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_InvalidAmount()"));
    lockdrop.earlyWithdrawLockedToken(5 ether, ALICE);
    vm.stopPrank();
  }

  function testRevert_LockdropEarlyWithdrawLockToken_WithdrawAmountIsZero()
    external
  {
    vm.startPrank(ALICE);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);

    lockdrop.lockToken(lockAmount, lockPeriod);

    // After Alice withdraw 0 USDC , the following criteria needs to satisfy:
    // 1. expect revert Lockdrop_ZeroAmountNotAllowed()

    vm.warp(lockdropConfig.startLockTimestamp() + 2 days);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_ZeroAmountNotAllowed()"));
    lockdrop.earlyWithdrawLockedToken(0, ALICE);
    vm.stopPrank();
  }

  function testRevert_LockdropEarlyWithdrawLockToken_WithdrawAmountExceedLockAmount()
    external
  {
    vm.startPrank(ALICE);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);

    // After Alice withdraw more than lock token amount USDC , the following criteria needs to satisfy:
    // 1. expect revert Lockdrop_InsufficientBalance()
    lockdrop.lockToken(lockAmount, lockPeriod);

    vm.warp(lockdropConfig.startLockTimestamp() + 2 days);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_InsufficientBalance()"));
    lockdrop.earlyWithdrawLockedToken(20 ether, ALICE);
    vm.stopPrank();
  }

  // Early withdraw after restricted withdrawal time but within decaying withdraw time which is first 12 hour
  // User cannot early withdraw more than half of lock token amount
  function testRevert_LockdropEarlyWithdrawLockToken_WithdrawDay4First12Hours_MoreThanOneTime()
    external
  {
    vm.startPrank(ALICE);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      ,
      bool aliceWihdrawOnce
    ) = lockdrop.lockdropStates(ALICE);

    // After Alice withdraw within decaying withdraw time more than 1 time, the following criteria needs to satisfy:
    // 1. expect revert Lockdrop_WithdrawNotAllowed()

    // Withdraw timestamp
    vm.warp(lockdropConfig.startLockTimestamp() + 3 days + 2 hours);
    assertEq(lockdrop.getEarlyWithdrawableAmount(ALICE), 8 ether);
    assertTrue(!aliceWihdrawOnce);
    lockdrop.earlyWithdrawLockedToken(5 ether, ALICE);
    (alicelockdropTokenAmount, alicelockPeriod, , aliceWihdrawOnce) = lockdrop
      .lockdropStates(ALICE);

    assertTrue(aliceWihdrawOnce);

    vm.expectRevert(abi.encodeWithSignature("Lockdrop_WithdrawNotAllowed()"));
    lockdrop.earlyWithdrawLockedToken(5 ether, ALICE);
    vm.stopPrank();
  }

  // Early withdraw after restricted withdrawal time and after decaying withdraw time
  // but still in lockdrop period which is last 12 hour of day 4
  // User cannot early withdraw more than the ratio of remaining time
  function testRevert_LockdropEarlyWithdrawLockToken_WithdrawDay4Last12Hours_MoreThanOneTime()
    external
  {
    vm.startPrank(ALICE);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      bool aliceP88Claimed,
      bool aliceWihdrawOnce
    ) = lockdrop.lockdropStates(ALICE);

    // After Alice withdraw after decaying withdraw time more than 1 time, the following criteria needs to satisfy:
    // 1. expect revert Lockdrop_WithdrawNotAllowed()

    // Withdraw timestamp: Day 4 after 12 hours
    vm.warp(lockdropConfig.startLockTimestamp() + 3 days + 18 hours);
    assertEq(lockdrop.getEarlyWithdrawableAmount(ALICE), 4 ether);

    lockdrop.earlyWithdrawLockedToken(4 ether, ALICE);
    (
      alicelockdropTokenAmount,
      alicelockPeriod,
      aliceP88Claimed,
      aliceWihdrawOnce
    ) = lockdrop.lockdropStates(ALICE);

    assertTrue(aliceWihdrawOnce);

    vm.expectRevert(abi.encodeWithSignature("Lockdrop_WithdrawNotAllowed()"));
    lockdrop.earlyWithdrawLockedToken(5 ether, ALICE);

    vm.stopPrank();
  }

  // ------ withdrawAll ------
  function testCorrectness_WhenWithdrawAllFromLockdropGateway() external {
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);

    vm.startPrank(ALICE);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);

    vm.stopPrank();
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);

    vm.startPrank(address(lockdrop));
    usdc.approve(address(poolDiamond), lockAmount);
    plp.approve(address(plpStaking), type(uint256).max);
    vm.stopPrank();

    vm.startPrank(DAVE);
    // Mint 604800 esP88 to Feeder
    esP88.mint(DAVE, 604800 ether);
    // Mint 302400 revenueToken to Feeder
    vm.deal(DAVE, 302400 ether);
    revenueToken.deposit{ value: 302400 ether }();

    lockdrop.stakePLP();

    esP88.approve(address(esP88Rewarder), type(uint256).max);
    // Feeder feed esP88 to esP88Rewarder
    // 604800 / 10 day rewardPerSec ~= 1 esP88
    esP88Rewarder.feed(604800 ether, 10 days);

    revenueToken.approve(address(revenueRewarder), type(uint256).max);
    // Feeder feed revenueToken to revenueRewarder
    // 302400 / 10 day rewardPerSec ~= 0.5 revenueToken
    revenueRewarder.feed(302400 ether, 10 days);
    vm.stopPrank();

    vm.warp(lockdropConfig.endLockTimestamp() + lockPeriod);

    vm.startPrank(address(lockdropGateway));
    lockdrop.withdrawAll(ALICE);
    (alicelockdropTokenAmount, alicelockPeriod, aliceP88Claimed, ) = lockdrop
      .lockdropStates(ALICE);
    vm.stopPrank();

    // Since Alice withdraw all then all rewards should be claimed
    // **FYI this is claim all first time for Alice.
    // After Alice withdrawAll, the following criteria needs to satisfy:

    // 1. Balance of Lockdrop Gateway PLP token should equal to totalPLPAmount state in lockdrop
    // 2. Balance of lockdrop PLP token should be 0
    // 3. Balance of EsP88 423350.128 tokens shold be tranfer to ALICE
    // 4. Balance of revenue native token 211667.088 tokens shold be tranfer to ALICE
    // 5. Alice is now deleted from lockdropStates so her lock token amount is 0
    // 6. Alice is now deleted from lockdropStates so her lock period is 0
    assertEq(
      plp.balanceOf(address(lockdropGateway)),
      lockdrop.totalPLPAmount()
    );
    assertEq(plp.balanceOf(address(lockdrop)), 0);

    // rewardForUser = (userShare * accumRewardPerShare) - userRewardDebt
    // Alice is onlyone locktoken => userShare = 16 ether
    // userRewardDebt = 0  because this first time for her claim rewards

    // esP88 from Rewarder = 423350.128 ether
    // accRewardPerShares = 423350.128 ether / 16 ether = 26539 wei
    // rewardForUser = (16 ether * 26539 wei) - 0 wei
    assertEq(esP88.balanceOf(ALICE), 423350.128 ether);

    // revenue native token from Rewarder = 211667.088 ether
    // accRewardPerShares = 211667.088 ether / 16 ether = 13269 wei
    // rewardForUser = (16 ether * 13269 wei) - 0 wei
    assertEq(ALICE.balance, 211667.088 ether);

    assertEq(alicelockdropTokenAmount, 0);
    assertEq(alicelockPeriod, 0);
  }

  function testRevert_WhenWithdrawAllFromLockdropGateway_ButWithdrawAllBeforeEndOfLockdrop()
    external
  {
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);

    vm.startPrank(ALICE);
    lockdrop.lockToken(lockAmount, lockPeriod);
    vm.stopPrank();

    // Since Alice withdraw all before end of lockdrop period.
    // 1. expect revert Lockdrop_ZeroTotalPLPAmount()
    vm.startPrank(address(lockdropGateway));
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_ZeroTotalPLPAmount()"));
    lockdrop.withdrawAll(ALICE);
    vm.stopPrank();
  }
}
