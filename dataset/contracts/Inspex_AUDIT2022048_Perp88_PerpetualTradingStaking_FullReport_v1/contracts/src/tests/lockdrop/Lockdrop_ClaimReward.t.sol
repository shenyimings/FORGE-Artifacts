// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Lockdrop_BaseTest, console, math } from "./Lockdrop_BaseTest.t.sol";

contract Lockdrop_ClaimReward is Lockdrop_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  // -------------------- claimAllP88 ----------------------------
  function testCorrectness_ClaimAllP88_OnlyOneUser() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 1000 ether);
    mockERC20.approve(address(lockdrop), 1000 ether);
    vm.warp(120000);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 aliceLockdropTokenAmount,
      uint256 aliceLockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);
    vm.stopPrank();

    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

    // After lockdrop period
    // Mint P88
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);
    vm.startPrank(address(this));
    mockP88Token.mint(address(this), 1000 ether);
    mockP88Token.approve(address(lockdrop), 1000 ether);
    lockdrop.allocateP88(100);
    vm.stopPrank();

    vm.startPrank(ALICE);
    lockdrop.claimAllP88(ALICE);
    vm.stopPrank();

    (aliceLockdropTokenAmount, aliceLockPeriod, aliceP88Claimed, ) = lockdrop
      .lockdropStates(ALICE);

    // After Alice claims her P88, the following criteria needs to satisfy:
    // 1. The amount of Alice's P88 should be 100
    // 2. The amount of lockdrop P88 should be 0
    // 3. Status of Alice claiming P88 should be true
    assertEq(mockP88Token.balanceOf(ALICE), 100);
    assertEq(mockP88Token.balanceOf(address(lockdrop)), 0);
    assertTrue(aliceP88Claimed);
  }

  function testCorrectness_ClaimAllP88_MultipleUser() external {
    uint256 lockAmount1 = 16 ether;
    uint256 lockPeriod1 = 8 days;
    uint256 lockAmount2 = 10 ether;
    uint256 lockPeriod2 = 20 days;

    // ------- Alice session -------
    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 1000 ether);
    mockERC20.approve(address(lockdrop), 1000 ether);
    vm.warp(120000);
    lockdrop.lockToken(lockAmount1, lockPeriod1);
    (
      uint256 aliceLockdropTokenAmount,
      uint256 aliceLockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);
    vm.stopPrank();
    assertEq(aliceLockdropTokenAmount, lockAmount1);
    assertEq(aliceLockPeriod, lockPeriod1);
    assertEq(lockdrop.totalAmount(), lockAmount1);
    assertEq(lockdrop.totalP88Weight(), lockAmount1 * lockPeriod1);
    assertTrue(!aliceP88Claimed);

    // ------- Bob session -------
    vm.startPrank(BOB);
    mockERC20.mint(BOB, 1000 ether);
    mockERC20.approve(address(lockdrop), 1000 ether);
    vm.warp(130000);
    lockdrop.lockToken(lockAmount2, lockPeriod2);
    (
      uint256 bobLockdropTokenAmount,
      uint256 bobLockPeriod,
      bool bobP88Claimed,

    ) = lockdrop.lockdropStates(BOB);
    vm.stopPrank();
    assertEq(bobLockdropTokenAmount, lockAmount2);
    assertEq(bobLockPeriod, lockPeriod2);
    assertEq(lockdrop.totalAmount(), lockAmount1 + lockAmount2);
    assertEq(
      lockdrop.totalP88Weight(),
      lockAmount1 * lockPeriod1 + lockAmount2 * lockPeriod2
    );
    assertTrue(!bobP88Claimed);

    // After lockdrop period
    // Mint P88
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);
    vm.startPrank(address(this));
    mockP88Token.mint(address(this), 1000 ether);
    mockP88Token.approve(address(lockdrop), 1000 ether);
    lockdrop.allocateP88(100);
    vm.stopPrank();

    // Alice claims her P88
    vm.startPrank(ALICE);
    lockdrop.claimAllP88(ALICE);
    vm.stopPrank();

    // Bob claims his P88
    vm.startPrank(BOB);
    lockdrop.claimAllP88(BOB);
    vm.stopPrank();

    (, , bobP88Claimed, ) = lockdrop.lockdropStates(BOB);
    (, , aliceP88Claimed, ) = lockdrop.lockdropStates(ALICE);
    // After claims her P88, the following criteria needs to satisfy:
    // 1. The amount of Alice's P88 should be 39
    // 2. The amount of Bob's P88 should be 60
    // 3. The amount of lockdrop P88 should be 1
    // 4. Status of Alice claiming P88 should be true
    // 5. Status of Bob claiming P88 should be true
    assertEq(mockP88Token.balanceOf(ALICE), 39);
    assertEq(mockP88Token.balanceOf(BOB), 60);
    assertEq(mockP88Token.balanceOf(address(lockdrop)), 1);

    (, , bobP88Claimed, ) = lockdrop.lockdropStates(BOB);
    (, , aliceP88Claimed, ) = lockdrop.lockdropStates(ALICE);

    // After claims her P88, the following criteria needs to satisfy:
    // 1. Status of Alice claiming P88 should be true
    // 2. Status of Bob claiming P88 should be true
    assertTrue(aliceP88Claimed);
    assertTrue(bobP88Claimed);
  }

  function testCorrectness_ClaimAllP88_MultipleUserWithNTimesLockAmount(
    uint8 multiplier
  ) external {
    // Alice lock xn token more than Bob with same lock period
    vm.assume(multiplier > 0 && multiplier < 100);
    uint256 userLockAmount = 10 ether;
    uint256 userLockPeriod = 8 days;

    // ------- Alice session -------
    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 1000 ether);
    mockERC20.approve(address(lockdrop), 1000 ether);
    vm.warp(120000);
    lockdrop.lockToken(userLockAmount * multiplier, userLockPeriod);
    (
      uint256 aliceLockdropTokenAmount,
      uint256 aliceLockdropLockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);
    vm.stopPrank();
    assertEq(aliceLockdropTokenAmount, userLockAmount * multiplier);
    assertEq(aliceLockdropLockPeriod, userLockPeriod);
    assertEq(lockdrop.totalAmount(), aliceLockdropTokenAmount);
    assertEq(
      lockdrop.totalP88Weight(),
      userLockAmount * multiplier * userLockPeriod
    );
    assertTrue(!aliceP88Claimed);

    // ------- Bob session -------
    vm.startPrank(BOB);
    mockERC20.mint(BOB, 1000 ether);
    mockERC20.approve(address(lockdrop), 1000 ether);
    vm.warp(130000);
    lockdrop.lockToken(userLockAmount, userLockPeriod);
    (
      uint256 bobLockdropTokenAmount,
      uint256 bobLockdropLockPeriod,
      bool bobP88Claimed,

    ) = lockdrop.lockdropStates(BOB);
    vm.stopPrank();
    assertEq(bobLockdropTokenAmount, userLockAmount);
    assertEq(bobLockdropLockPeriod, userLockPeriod);
    assertEq(
      lockdrop.totalAmount(),
      bobLockdropTokenAmount + aliceLockdropTokenAmount
    );
    assertEq(
      lockdrop.totalP88Weight(),
      userLockAmount * userLockPeriod * (1 + multiplier)
    );
    assertTrue(!bobP88Claimed);

    // After lockdrop period
    // Mint P88
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);
    vm.startPrank(address(this));
    mockP88Token.mint(address(this), 1000 ether);
    mockP88Token.approve(address(lockdrop), 1000 ether);
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
        (mockP88Token.balanceOf(BOB) * multiplier),
        mockP88Token.balanceOf(ALICE),
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
    mockERC20.mint(ALICE, 1000 ether);
    mockERC20.approve(address(lockdrop), 1000 ether);
    vm.warp(120000);
    lockdrop.lockToken(userLockAmount, userLockPeriod * multiplier);
    (
      uint256 aliceLockdropTokenAmount,
      uint256 aliceLockdropLockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);
    vm.stopPrank();
    assertEq(aliceLockdropTokenAmount, userLockAmount);
    assertEq(aliceLockdropLockPeriod, userLockPeriod * multiplier);
    assertEq(lockdrop.totalAmount(), aliceLockdropTokenAmount);
    assertEq(
      lockdrop.totalP88Weight(),
      userLockAmount * multiplier * userLockPeriod
    );
    assertTrue(!aliceP88Claimed);

    // ------- Bob session -------
    vm.startPrank(BOB);
    mockERC20.mint(BOB, 1000 ether);
    mockERC20.approve(address(lockdrop), 1000 ether);
    vm.warp(130000);
    lockdrop.lockToken(userLockAmount, userLockPeriod);
    (
      uint256 bobLockdropTokenAmount,
      uint256 bobLockdropLockPeriod,
      bool bobP88Claimed,

    ) = lockdrop.lockdropStates(BOB);
    vm.stopPrank();
    assertEq(bobLockdropTokenAmount, userLockAmount);
    assertEq(bobLockdropLockPeriod, userLockPeriod);
    assertEq(
      lockdrop.totalAmount(),
      bobLockdropTokenAmount + aliceLockdropTokenAmount
    );
    assertEq(
      lockdrop.totalP88Weight(),
      userLockAmount * userLockPeriod * (1 + multiplier)
    );
    assertTrue(!bobP88Claimed);

    // After lockdrop period
    // Mint P88
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);
    vm.startPrank(address(this));
    mockP88Token.mint(address(this), 1000 ether);
    mockP88Token.approve(address(lockdrop), 1000 ether);
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
        (mockP88Token.balanceOf(BOB) * multiplier),
        mockP88Token.balanceOf(ALICE),
        1
      )
    );

    assertTrue(aliceP88Claimed);
    assertTrue(bobP88Claimed);
  }

  function testRevert_ClaimAllP88_TotalP88NotSet() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 1000 ether);
    mockERC20.approve(address(lockdrop), 1000 ether);
    vm.warp(120000);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 aliceLockdropTokenAmount,
      uint256 aliceLockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);
    vm.stopPrank();
    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, lockPeriod);
    assertTrue(!aliceP88Claimed);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

    // After lockdrop period
    // Mint P88
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);

    vm.startPrank(address(this));
    mockP88Token.mint(address(this), 1000 ether);
    mockP88Token.approve(address(lockdrop), 1000 ether);
    vm.stopPrank();

    vm.startPrank(ALICE);
    // Haven't call allocateP88
    vm.expectRevert(
      abi.encodeWithSignature("Lockdrop_ZeroTotalP88NotAllowed()")
    );
    lockdrop.claimAllP88(ALICE);
    vm.stopPrank();
  }

  function testRevert_ClaimAllP88_AlreadyClaimedReward() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 1000 ether);
    mockERC20.approve(address(lockdrop), 1000 ether);
    vm.warp(120000);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (
      uint256 aliceLockdropTokenAmount,
      uint256 aliceLockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);
    vm.stopPrank();
    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, lockPeriod);
    assertTrue(!aliceP88Claimed);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

    // After lockdrop period
    // Mint P88
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);

    vm.startPrank(address(this));
    mockP88Token.mint(address(this), 1000 ether);
    mockP88Token.approve(address(lockdrop), 1000 ether);
    lockdrop.allocateP88(100);
    vm.stopPrank();

    vm.startPrank(ALICE);
    lockdrop.claimAllP88(ALICE);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_P88AlreadyClaimed()"));
    lockdrop.claimAllP88(ALICE);
    vm.stopPrank();
  }
}
