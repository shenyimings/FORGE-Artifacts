// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Lockdrop_BaseTest, console } from "./Lockdrop_BaseTest.t.sol";

contract Lockdrop_WithdrawLockToken is Lockdrop_BaseTest {
  function setUp() public override {
    super.setUp();
    mockPLPToken.setMinter(address(this), true);
  }

  // ------ earlyWithdrawLockedToken ------
  function testCorrectness_LockdropEarlyWithdrawLockToken_WithdrawWithinFirst3Days()
    external
  {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      ,
      bool aliceWithdrawOnce
    ) = lockdrop.lockdropStates(ALICE);

    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(alicelockdropTokenAmount, lockAmount);
    assertEq(alicelockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

    // Withdraw timestamp
    vm.warp(lockdropConfig.startLockTimestamp() + 1 days);
    assertTrue(!aliceWithdrawOnce);
    lockdrop.earlyWithdrawLockedToken(5 ether, ALICE);
    (alicelockdropTokenAmount, alicelockPeriod, , aliceWithdrawOnce) = lockdrop
      .lockdropStates(ALICE);
    vm.stopPrank();

    // After Alice withdraw the ERC20 token from the first 3 days, the following criteria needs to satisfy:
    // 1. Balance of Alice's ERC20 token should be 9
    // 2. The amount of Alice's lockdrop token should be 11
    // 3. The number of lock period should be 8 days
    // 4. The total amount of lock token should be 11
    // 5. The total weight of P88 should be 11 * 8 days
    // 6. Alice restrictedWithdrawn state should remain false

    assertEq(mockERC20.balanceOf(ALICE), 9 ether);
    assertEq(alicelockdropTokenAmount, 11 ether);
    assertEq(alicelockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), 11 ether);
    assertEq(lockdrop.totalP88Weight(), 11 ether * lockPeriod);
    assertTrue(!aliceWithdrawOnce);
  }

  function testCorrectness_LockdropEarlyWithdrawLockToken_WithdrawAllWithinFirst3Days()
    external
  {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      ,
      bool aliceWithdrawOnce
    ) = lockdrop.lockdropStates(ALICE);

    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(alicelockdropTokenAmount, lockAmount);
    assertEq(alicelockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

    // Withdraw timestamp
    vm.warp(lockdropConfig.startLockTimestamp() + 1 days);
    assertTrue(!aliceWithdrawOnce);
    lockdrop.earlyWithdrawLockedToken(lockAmount, ALICE);
    (alicelockdropTokenAmount, alicelockPeriod, , aliceWithdrawOnce) = lockdrop
      .lockdropStates(ALICE);

    vm.stopPrank();
    // After Alice withdraw the ERC20 token from the first 3 days, the following criteria needs to satisfy:
    // 1. Balance of Alice's ERC20 token should be 20
    // 2. The amount of Alice's lockdrop token should be 0
    // 3. The number of lock period should be 0
    // 4. The total amount of lock token should be 0
    // 5. The total weight of P88 should be 0
    // 6 Alice restrictedWithdrawn should remain false
    assertEq(mockERC20.balanceOf(ALICE), 20 ether);
    assertEq(alicelockdropTokenAmount, 0);
    assertEq(alicelockPeriod, 0);
    assertEq(lockdrop.totalAmount(), 0);
    assertEq(lockdrop.totalP88Weight(), 0);
    assertTrue(!aliceWithdrawOnce);
  }

  function testCorrectness_LockdropEarlyWithdrawLockToken_MultipleWithdrawWithinFirst3Days()
    external
  {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      bool aliceP88Claimed,
      bool aliceWithdrawOnce
    ) = lockdrop.lockdropStates(ALICE);
    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(alicelockdropTokenAmount, lockAmount);
    assertEq(alicelockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

    // Withdraw timestamp
    vm.warp(lockdropConfig.startLockTimestamp() + 1 days);
    assertTrue(!aliceWithdrawOnce);
    lockdrop.earlyWithdrawLockedToken(5 ether, ALICE);
    (alicelockdropTokenAmount, alicelockPeriod, , aliceWithdrawOnce) = lockdrop
      .lockdropStates(ALICE);

    // After Alice withdraw the ERC20 token within the first 3 days, the following criteria needs to satisfy:
    // 1. Balance of Alice's ERC20 token should be 9
    // 2. The amount of Alice's lockdrop token should be 11
    // 3. The number of lock period should be 8 days
    // 4. The total amount of lock token should be 11
    // 5. The total weight of P88 should be 11 * 8 days
    // 6. Alice restrictedWithdrawn should remain false

    assertEq(mockERC20.balanceOf(ALICE), 9 ether);
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

    // After Alice withdraw all of her ERC20 token within the first 3 days, the following criteria needs to satisfy:
    // 1. Balance of Alice's ERC20 token should be 20
    // 2. Alice is now deleted from lockdropStates so her lock token amount is 0
    // 3. Alice is now deleted from lockdropStates so her lock period is 0
    // 4. Alice restrictedWithdrawn should remain false

    assertEq(mockERC20.balanceOf(ALICE), 20 ether);
    assertEq(alicelockdropTokenAmount, 0);
    assertEq(alicelockPeriod, 0);
    assertTrue(!aliceWithdrawOnce);
  }

  function testCorrectness_LockdropEarlyWithdrawLockToken_WithdrawDay4First12Hours()
    external
  {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      ,
      bool aliceWihdrawOnce
    ) = lockdrop.lockdropStates(ALICE);

    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(alicelockdropTokenAmount, lockAmount);
    assertEq(alicelockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

    // Withdraw timestamp
    vm.warp(lockdropConfig.startLockTimestamp() + 3 days + 2 hours);
    assertEq(lockdrop.getEarlyWithdrawableAmount(ALICE), 8 ether);
    assertTrue(!aliceWihdrawOnce);
    lockdrop.earlyWithdrawLockedToken(5 ether, ALICE);
    (alicelockdropTokenAmount, alicelockPeriod, , aliceWihdrawOnce) = lockdrop
      .lockdropStates(ALICE);

    // After Alice withdraw the ERC20 token on day 4 in the first 12 hours, the following criteria needs to satisfy:
    // 1. Balance of Alice's ERC20 token should be 9
    // 2. The amount of Alice's lockdrop token should be 11
    // 3. The number of lock period should be 8 days
    // 4. The total amount of lock token should be 11
    // 5. The total weight of P88 should be 11 * 8 days
    // 6. Alice restrictedWithdrawn state should be set to true

    assertEq(mockERC20.balanceOf(ALICE), 9 ether);
    assertEq(alicelockdropTokenAmount, 11 ether);
    assertEq(alicelockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), 11 ether);
    assertEq(lockdrop.totalP88Weight(), 11 ether * lockPeriod);
    assertTrue(aliceWihdrawOnce);
  }

  function testCorrectness_LockdropEarlyWithdrawLockToken_WithdrawDay4Last12Hours()
    external
  {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      bool aliceP88Claimed,
      bool aliceWihdrawOnce
    ) = lockdrop.lockdropStates(ALICE);
    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(alicelockdropTokenAmount, lockAmount);
    assertEq(alicelockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);
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

    // After Alice withdraw the ERC20 token on day 4 in the last 12 hours, the following criteria needs to satisfy:
    // 1. Balance of Alice's ERC20 token should be 8
    // 2. The amount of Alice's lockdrop token should be 12
    // 3. Alice hasn't claim her P88 so should be false
    // 4. The number of lock period should be 8 days
    // 5. The total amount of lock token should be 12
    // 6. The total weight of P88 should be 12 * 8 days
    // 7. Alice restrictedWithdrawn state should be set to true

    assertEq(mockERC20.balanceOf(ALICE), 8 ether);
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
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);
    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(alicelockdropTokenAmount, lockAmount);
    assertEq(alicelockPeriod, lockPeriod);
    assertTrue(!aliceP88Claimed);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

    vm.warp(lockdropConfig.startLockTimestamp() + 4 days + 1 hours);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_NotInLockdropPeriod()"));
    lockdrop.earlyWithdrawLockedToken(5 ether, ALICE);
    vm.stopPrank();
  }

  function testRevert_LockdropEarlyWithdrawLockToken_WithdrawDay4First12HoursInvalidAmount()
    external
  {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);

    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);
    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(alicelockdropTokenAmount, lockAmount);
    assertEq(alicelockPeriod, lockPeriod);
    assertTrue(!aliceP88Claimed);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

    // Withdraw timestamp
    vm.warp(lockdropConfig.startLockTimestamp() + 3 days + 2 hours);
    // Withdraw more than 50%
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_InvalidAmount()"));
    lockdrop.earlyWithdrawLockedToken(10 ether, ALICE);
    vm.stopPrank();
  }

  function testRevert_LockdropEarlyWithdrawLockToken_WithdrawDay4Last12HoursInvalidAmount()
    external
  {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);

    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);
    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(alicelockdropTokenAmount, lockAmount);
    assertEq(alicelockPeriod, lockPeriod);
    assertTrue(!aliceP88Claimed);

    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

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
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);

    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);
    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(alicelockdropTokenAmount, lockAmount);
    assertEq(alicelockPeriod, lockPeriod);
    assertTrue(!aliceP88Claimed);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

    vm.warp(lockdropConfig.startLockTimestamp() + 2 days);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_ZeroAmountNotAllowed()"));
    lockdrop.earlyWithdrawLockedToken(0, ALICE);
    vm.stopPrank();
  }

  function testRevert_LockdropEarlyWithdrawLockToken_WithdrawAmountExceedLockAmount()
    external
  {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);

    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);
    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(alicelockdropTokenAmount, lockAmount);
    assertEq(alicelockPeriod, lockPeriod);
    assertTrue(!aliceP88Claimed);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

    vm.warp(lockdropConfig.startLockTimestamp() + 2 days);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_InsufficientBalance()"));
    lockdrop.earlyWithdrawLockedToken(20 ether, ALICE);
    vm.stopPrank();
  }

  function testRevert_LockdropEarlyWithdrawLockToken_WithdrawDay4First12Hours_MoreThanOneTime()
    external
  {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      ,
      bool aliceWihdrawOnce
    ) = lockdrop.lockdropStates(ALICE);
    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(alicelockdropTokenAmount, lockAmount);
    assertEq(alicelockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

    // Withdraw timestamp
    vm.warp(lockdropConfig.startLockTimestamp() + 3 days + 2 hours);
    assertEq(lockdrop.getEarlyWithdrawableAmount(ALICE), 8 ether);
    assertTrue(!aliceWihdrawOnce);
    lockdrop.earlyWithdrawLockedToken(5 ether, ALICE);
    (alicelockdropTokenAmount, alicelockPeriod, , aliceWihdrawOnce) = lockdrop
      .lockdropStates(ALICE);

    assertEq(mockERC20.balanceOf(ALICE), 9 ether);
    assertEq(alicelockdropTokenAmount, 11 ether);
    assertEq(alicelockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), 11 ether);
    assertEq(lockdrop.totalP88Weight(), 11 ether * lockPeriod);
    assertTrue(aliceWihdrawOnce);

    vm.expectRevert(abi.encodeWithSignature("Lockdrop_WithdrawNotAllowed()"));
    lockdrop.earlyWithdrawLockedToken(5 ether, ALICE);
    vm.stopPrank();
  }

  function testRevert_LockdropEarlyWithdrawLockToken_WithdrawDay4Last12Hours_MoreThanOneTime()
    external
  {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      bool aliceP88Claimed,
      bool aliceWihdrawOnce
    ) = lockdrop.lockdropStates(ALICE);
    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(alicelockdropTokenAmount, lockAmount);
    assertEq(alicelockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);
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
    assertEq(mockERC20.balanceOf(ALICE), 8 ether);
    assertEq(alicelockdropTokenAmount, 12 ether);
    assertEq(alicelockPeriod, lockPeriod);
    assertTrue(!aliceP88Claimed);
    assertEq(lockdrop.totalAmount(), 12 ether);
    assertEq(lockdrop.totalP88Weight(), 12 ether * lockPeriod);
    assertTrue(aliceWihdrawOnce);

    vm.expectRevert(abi.encodeWithSignature("Lockdrop_WithdrawNotAllowed()"));
    lockdrop.earlyWithdrawLockedToken(5 ether, ALICE);

    vm.stopPrank();
  }

  function testCorrectness_LockdropEarlyWithdrawLockToken_WithdrawNative()
    external
  {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    vm.deal(ALICE, 20 ether);
    mockMatic.deposit{ value: lockAmount }();
    mockMatic.approve(address(lockdropWMATIC), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    lockdropWMATIC.lockToken(lockAmount, lockPeriod);
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      ,
      bool aliceWithdrawOnce
    ) = lockdropWMATIC.lockdropStates(ALICE);

    assertEq(address(ALICE).balance, 4 ether);
    assertEq(alicelockdropTokenAmount, lockAmount);
    assertEq(alicelockPeriod, lockPeriod);
    assertEq(lockdropWMATIC.totalAmount(), lockAmount);
    assertEq(lockdropWMATIC.totalP88Weight(), lockAmount * lockPeriod);

    // Withdraw timestamp
    vm.warp(lockdropConfig.startLockTimestamp() + 1 days);
    assertTrue(!aliceWithdrawOnce);
    lockdropWMATIC.earlyWithdrawLockedToken(5 ether, ALICE);
    (
      alicelockdropTokenAmount,
      alicelockPeriod,
      ,
      aliceWithdrawOnce
    ) = lockdropWMATIC.lockdropStates(ALICE);
    vm.stopPrank();

    // After Alice withdraw the MATIC token from the first 3 days, the following criteria needs to satisfy:
    // 1. Balance of Alice's MATIC token should be 9
    // 2. The amount of Alice's lockdrop token should be 11
    // 3. The number of lock period should be 8 days
    // 4. The total amount of lock token should be 11
    // 5. The total weight of P88 should be 11 * 8 days
    // 6. Alice restrictedWithdrawn state should remain false

    assertEq(address(ALICE).balance, 9 ether);
    assertEq(alicelockdropTokenAmount, 11 ether);
    assertEq(alicelockPeriod, lockPeriod);
    assertEq(lockdropWMATIC.totalAmount(), 11 ether);
    assertEq(lockdropWMATIC.totalP88Weight(), 11 ether * lockPeriod);
    assertTrue(!aliceWithdrawOnce);
  }
}
