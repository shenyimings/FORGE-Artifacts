pragma solidity 0.8.17;

import { Lockdrop_BaseTest, console } from "./Lockdrop_BaseTest.t.sol";

contract Lockdrop_AllocateP88 is Lockdrop_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_AllocateP88() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(120000);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);
    vm.stopPrank();
    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

    // After lockdrop period
    // Mint P88
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);

    vm.startPrank(address(this));
    mockP88Token.mint(address(this), 100 ether);
    mockP88Token.approve(address(lockdrop), 1000 ether);
    lockdrop.allocateP88(100);
    vm.stopPrank();

    // After lockdrop period ends, allocating P88 is called, the following criteria needs to satisfy:
    assertEq(lockdrop.totalP88(), 100);
    assertEq(mockP88Token.balanceOf(address(lockdrop)), 100);
  }

  function testRevert_AllocateP88_CallAllocateMultipleTimes() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(120000);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);
    vm.stopPrank();
    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

    // After lockdrop period
    // Mint P88
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);
    vm.startPrank(address(this));
    mockP88Token.mint(address(this), 100 ether);
    mockP88Token.approve(address(lockdrop), 1000 ether);
    lockdrop.allocateP88(100);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_AlreadyAllocateP88()"));
    lockdrop.allocateP88(100);
    vm.stopPrank();
  }
}
