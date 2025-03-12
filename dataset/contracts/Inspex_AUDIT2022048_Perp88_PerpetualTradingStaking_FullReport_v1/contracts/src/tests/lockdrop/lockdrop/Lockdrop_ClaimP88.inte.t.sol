// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Lockdrop_BaseTest, console, math } from "./Lockdrop_BaseTest.inte.t.sol";

contract Lockdrop_ClaimP88 is Lockdrop_BaseTest {
  uint256 lockAmount_ALICE;
  uint256 lockPeriod_ALICE;

  uint256 lockAmount_BOB;
  uint256 lockPeriod_BOB;

  function setUp() public override {
    super.setUp();

    lockAmount_ALICE = 15 ether;
    lockPeriod_ALICE = 20 days;
    lockAmount_BOB = 10 ether;
    lockPeriod_BOB = 20 days;

    vm.startPrank(ALICE);
    usdc.mint(ALICE, 1000 ether);
    usdc.approve(address(lockdrop), 1000 ether);
    vm.stopPrank();

    vm.startPrank(BOB);
    usdc.mint(BOB, 1000 ether);
    usdc.approve(address(lockdrop), 1000 ether);
    vm.stopPrank();
  }

  function testCorrectness_UserClaimAllP88_WhenOnlyOneUserInAShare() external {
    // ------- Alice session -------
    vm.startPrank(ALICE);
    // 1 day later
    vm.warp(1 days);
    lockdrop.lockToken(lockAmount_ALICE, lockPeriod_ALICE);
    (
      uint256 aliceLockdropTokenAmount,
      uint256 aliceLockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);
    vm.stopPrank();

    // After lockdrop period
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);

    // Mint P88 for Allocator
    vm.startPrank(DAVE);
    p88.mint(DAVE, 100 ether);
    p88.approve(address(lockdrop), 100 ether);
    lockdrop.allocateP88(100 ether);
    vm.stopPrank();

    assertEq(lockdrop.totalP88(), 100 ether);
    assertEq(p88.balanceOf(address(lockdrop)), 100 ether);

    vm.startPrank(ALICE);
    lockdrop.claimAllP88(ALICE);
    vm.stopPrank();

    (aliceLockdropTokenAmount, aliceLockPeriod, aliceP88Claimed, ) = lockdrop
      .lockdropStates(ALICE);

    // After Alice claims her P88, the following criteria needs to satisfy:
    // 1. The amount of Alice's P88 should be 100
    // 2. The amount of lockdrop P88 should be 0
    // 3. Status of Alice claiming P88 should be true

    // In this case Alice is onlyone who lock tokens
    //  p88Reward = (totalAllocateP88 * AliceP88Weight) / totalP88Weight

    // p88Reward_ALICE = (100 ether * (15 ether *  20 days)) / (15 ether * 20 days)
    assertEq(p88.balanceOf(ALICE), 100 ether);
    assertEq(p88.balanceOf(address(lockdrop)), 0);
    assertTrue(aliceP88Claimed);
  }

  function testCorrectness_ClaimAllP88_WhenMultipleUserInAShare() external {
    // ------- Alice session -------
    vm.startPrank(ALICE);
    // 1 day later
    vm.warp(1 days);
    lockdrop.lockToken(lockAmount_ALICE, lockPeriod_ALICE);
    (
      uint256 aliceLockdropTokenAmount,
      uint256 aliceLockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);
    vm.stopPrank();

    // ------- Bob session -------
    vm.startPrank(BOB);
    lockdrop.lockToken(lockAmount_BOB, lockPeriod_BOB);
    (
      uint256 bobLockdropTokenAmount,
      uint256 bobLockPeriod,
      bool bobP88Claimed,

    ) = lockdrop.lockdropStates(BOB);
    vm.stopPrank();

    // After lockdrop period
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);

    // Mint P88 for Allocator
    vm.startPrank(DAVE);
    p88.mint(DAVE, 100 ether);
    p88.approve(address(lockdrop), 100 ether);
    lockdrop.allocateP88(100 ether);
    vm.stopPrank();

    assertEq(lockdrop.totalP88(), 100 ether);
    assertEq(p88.balanceOf(address(lockdrop)), 100 ether);

    // Alice claims her P88
    vm.startPrank(ALICE);
    lockdrop.claimAllP88(ALICE);
    vm.stopPrank();

    // Bob claims his P88
    vm.startPrank(BOB);
    lockdrop.claimAllP88(BOB);
    vm.stopPrank();

    (aliceLockdropTokenAmount, aliceLockPeriod, aliceP88Claimed, ) = lockdrop
      .lockdropStates(ALICE);

    (bobLockdropTokenAmount, bobLockPeriod, bobP88Claimed, ) = lockdrop
      .lockdropStates(BOB);

    // After Alice claims her P88, the following criteria needs to satisfy:
    // 1. The amount of Alice's P88 should be 60
    // 2. The amount of lockdrop P88 should be 0
    // 3. Status of Alice claiming P88 should be true

    // In this case Alice and Bob are in the share
    //  p88Reward = (totalAllocateP88 * AliceP88Weight) / totalP88Weight

    // p88Reward_ALICE = (100 ether * (15 ether *  20 days)) / ((15 ether * 20 days) + (10 ether * 20 days)) = 60 ether
    assertEq(p88.balanceOf(ALICE), 60 ether);
    assertEq(p88.balanceOf(address(lockdrop)), 0);
    assertTrue(aliceP88Claimed);

    // After Bob claims his P88, the following criteria needs to satisfy:
    // 1. The amount of Bob's P88 should be 40
    // 2. Status of Bob claiming P88 should be true

    // p88Reward_ALICE = (100 ether * (10 ether *  20 days)) / ((15 ether * 20 days) + (10 ether * 20 days)) = 40 ether
    assertEq(p88.balanceOf(BOB), 40 ether);
    assertTrue(bobP88Claimed);
  }

  function testCorrectness_UserClaimAllP88_WhenMultipleUserWithNTimesLockAmount(
    uint8 multiplier
  ) external {
    // Alice lock xn token more than Bob with same lock period
    vm.assume(multiplier > 0 && multiplier < 100);
    uint256 userLockAmount = 10 ether;
    uint256 userLockPeriod = 8 days;

    // ------- Alice session -------
    vm.startPrank(ALICE);
    vm.warp(1 days);
    lockdrop.lockToken(userLockAmount * multiplier, userLockPeriod);
    (
      uint256 aliceLockdropTokenAmount,
      uint256 aliceLockdropLockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);

    assertEq(
      lockdrop.totalP88Weight(),
      userLockAmount * multiplier * userLockPeriod
    );

    vm.stopPrank();

    // ------- Bob session -------
    vm.startPrank(BOB);
    vm.warp(1 days);
    lockdrop.lockToken(userLockAmount, userLockPeriod);
    (
      uint256 bobLockdropTokenAmount,
      uint256 bobLockdropLockPeriod,
      bool bobP88Claimed,

    ) = lockdrop.lockdropStates(BOB);
    vm.stopPrank();

    assertEq(
      lockdrop.totalP88Weight(),
      userLockAmount * userLockPeriod * (1 + multiplier)
    );

    // After lockdrop period
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);

    // Mint P88 for Allocator
    vm.startPrank(DAVE);
    p88.mint(DAVE, 1000 ether);
    p88.approve(address(lockdrop), 1000 ether);
    lockdrop.allocateP88(100 ether);
    vm.stopPrank();

    // Alice claims her P88
    vm.startPrank(ALICE);
    lockdrop.claimAllP88(ALICE);
    vm.stopPrank();

    // Bob claims his P88
    vm.startPrank(BOB);
    lockdrop.claimAllP88(BOB);
    vm.stopPrank();

    (bobLockdropTokenAmount, bobLockdropLockPeriod, bobP88Claimed, ) = lockdrop
      .lockdropStates(BOB);
    (
      aliceLockdropTokenAmount,
      aliceLockdropLockPeriod,
      aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);

    // After claims her P88, the following criteria needs to satisfy:
    // 1. The amount of Alice's P88 should be almost equal to xN of Bob amount)
    // 2. Status of Alice claiming P88 should be true
    // 3. Status of Bob claiming P88 should be true
    assertTrue(
      math.almostEqual(
        (p88.balanceOf(BOB) * multiplier),
        p88.balanceOf(ALICE),
        1
      )
    );
    assertTrue(aliceP88Claimed);
    assertTrue(bobP88Claimed);
  }

  function testCorrectness_ClaimAllP88_MultipleUserWithNTimesLockPeriod(
    uint8 multiplier
  ) external {
    // Alice lock xN more lock period than Bob with same lock amount
    vm.assume(multiplier > 0 && multiplier < 40);
    uint256 userLockAmount = 10 ether;
    uint256 userLockPeriod = 8 days;

    // ------- Alice session -------
    vm.startPrank(ALICE);
    vm.warp(1 days);
    lockdrop.lockToken(userLockAmount, userLockPeriod * multiplier);
    (
      uint256 aliceLockdropTokenAmount,
      uint256 aliceLockdropLockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);

    assertEq(
      lockdrop.totalP88Weight(),
      userLockAmount * multiplier * userLockPeriod
    );

    vm.stopPrank();

    // ------- Bob session -------
    vm.startPrank(BOB);
    vm.warp(1 days);
    lockdrop.lockToken(userLockAmount, userLockPeriod);
    (
      uint256 bobLockdropTokenAmount,
      uint256 bobLockdropLockPeriod,
      bool bobP88Claimed,

    ) = lockdrop.lockdropStates(BOB);
    vm.stopPrank();

    assertEq(
      lockdrop.totalP88Weight(),
      userLockAmount * userLockPeriod * (1 + multiplier)
    );

    // After lockdrop period
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);

    // Mint P88 for Allocator
    vm.startPrank(DAVE);
    p88.mint(DAVE, 1000 ether);
    p88.approve(address(lockdrop), 1000 ether);
    lockdrop.allocateP88(100 ether);
    vm.stopPrank();

    // Alice claims her P88
    vm.startPrank(ALICE);
    lockdrop.claimAllP88(ALICE);
    vm.stopPrank();

    // Bob claims his P88
    vm.startPrank(BOB);
    lockdrop.claimAllP88(BOB);
    vm.stopPrank();

    (bobLockdropTokenAmount, bobLockdropLockPeriod, bobP88Claimed, ) = lockdrop
      .lockdropStates(BOB);
    (
      aliceLockdropTokenAmount,
      aliceLockdropLockPeriod,
      aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);

    // After claims her P88, the following criteria needs to satisfy:
    // 1. The amount of Alice's P88 should be greater than or equal to xN of Bob amount)
    // 2. Status of Alice claiming P88 should be true
    // 3. Status of Bob claiming P88 should be true
    assertTrue(
      math.almostEqual(
        (p88.balanceOf(BOB) * multiplier),
        p88.balanceOf(ALICE),
        1
      )
    );

    assertTrue(aliceP88Claimed);
    assertTrue(bobP88Claimed);
  }

  function testRevert_WhenUserClaimAllP88_ButNotAllocateP88() external {
    // ------- Alice session -------
    vm.startPrank(ALICE);
    vm.warp(1 days);
    lockdrop.lockToken(lockAmount_ALICE, lockPeriod_ALICE);
    (
      uint256 aliceLockdropTokenAmount,
      uint256 aliceLockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);

    // After lockdrop period
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);

    // After Alice claims her P88 but owner didn't allocate P88, the following criteria needs to satisfy:
    // 1. expect revert Lockdrop_ZeroTotalP88NotAllowed()

    // Haven't call allocateP88
    vm.expectRevert(
      abi.encodeWithSignature("Lockdrop_ZeroTotalP88NotAllowed()")
    );
    lockdrop.claimAllP88(ALICE);

    vm.stopPrank();
  }

  function testRevert_WhenUserClaimAllP88_ButAlreadyClaimedReward() external {
    // ------- Alice session -------
    vm.startPrank(ALICE);
    // 1 day later
    vm.warp(1 days);
    lockdrop.lockToken(lockAmount_ALICE, lockPeriod_ALICE);
    vm.stopPrank();

    // After lockdrop period
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);

    // Mint P88 for Allocator
    vm.startPrank(DAVE);
    p88.mint(DAVE, 100 ether);
    p88.approve(address(lockdrop), 100 ether);
    lockdrop.allocateP88(100 ether);
    vm.stopPrank();

    assertEq(lockdrop.totalP88(), 100 ether);
    assertEq(p88.balanceOf(address(lockdrop)), 100 ether);

    // After Alice claims her P88 multiple times, the following criteria needs to satisfy:
    // 1. expect revert Lockdrop_P88AlreadyClaimed()

    vm.startPrank(ALICE);
    lockdrop.claimAllP88(ALICE);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_P88AlreadyClaimed()"));
    lockdrop.claimAllP88(ALICE);
    vm.stopPrank();
  }
}
