pragma solidity 0.8.17;

import { Lockdrop_BaseTest } from "./Lockdrop_BaseTest.inte.t.sol";

contract Lockdrop_AllocateP88 is Lockdrop_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_WhenUserLockToken_ThenAllocateP88() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    // ------- Alice session -------
    vm.startPrank(ALICE);

    // mint 20 USDC for ALICE
    usdc.mint(ALICE, 20 ether);
    usdc.approve(address(lockdrop), 20 ether);

    // 1 days later.
    vm.warp(1 days);

    // ALICE Lock 16 USDC for 8 days
    lockdrop.lockToken(lockAmount, lockPeriod);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);
    vm.stopPrank();

    assertEq(usdc.balanceOf(ALICE), 4 ether);
    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

    // After lockdrop period
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);

    // Mint P88 for Allocator
    vm.startPrank(DAVE);
    p88.mint(DAVE, 100 ether);
    p88.approve(address(lockdrop), 100 ether);
    lockdrop.allocateP88(100 ether);
    vm.stopPrank();

    // After lockdrop period ends, allocating P88 is called, the following criteria needs to satisfy:
    // 1. Total P88 Tokens should be 100 tokens
    assertEq(lockdrop.totalP88(), 100 ether);
    assertEq(p88.balanceOf(address(lockdrop)), 100 ether);
  }

  function testRevert_AllocateP88_CallAllocateMultipleTimes() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    // ------- Alice session -------
    vm.startPrank(ALICE);
    // mint 20 USDC for ALICE
    usdc.mint(ALICE, 20 ether);
    usdc.approve(address(lockdrop), 20 ether);
    // 1 days later.
    vm.warp(1 days);

    // ALICE Lock 16 USDC for 8 days
    lockdrop.lockToken(lockAmount, lockPeriod);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);
    vm.stopPrank();

    assertEq(usdc.balanceOf(ALICE), 4 ether);
    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

    // After lockdrop period
    // Mint P88 for Allocator
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);
    vm.startPrank(DAVE);
    p88.mint(DAVE, 100 ether);
    p88.approve(address(lockdrop), 1000 ether);
    lockdrop.allocateP88(100 ether);

    // Expect Revert
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_AlreadyAllocateP88()"));
    lockdrop.allocateP88(100 ether);
    vm.stopPrank();
  }
}
