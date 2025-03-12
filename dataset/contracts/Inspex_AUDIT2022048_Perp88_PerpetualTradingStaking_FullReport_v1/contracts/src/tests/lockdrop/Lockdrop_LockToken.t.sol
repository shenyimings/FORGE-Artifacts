// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Lockdrop_BaseTest, console, MockErc20 } from "./Lockdrop_BaseTest.t.sol";

contract Lockdrop_LockToken is Lockdrop_BaseTest {
  MockErc20 internal mock2ERC20;

  function setUp() public override {
    super.setUp();
    mock2ERC20 = new MockErc20("Mock Token2", "MT2", 18);
  }

  function testCorrectness_LockdropLockToken() external {
    uint256 lockAmount1 = 16 ether;
    uint256 lockPeriod1 = 8 days;

    // ------- Alice session -------
    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 4 hours);
    lockdrop.lockToken(lockAmount1, lockPeriod1);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);
    vm.stopPrank();
    // After Alice lock the ERC20 token, the following criteria needs to satisfy:
    // 1. Balance of Alice's ERC20 token should be 4
    // 2. The amount of Alice's lockdrop token should be 16
    // 3. The number of lock period should be 8 days
    // 4. The total amount of lock token should be 16
    // 5. The total P88 weight should be 16 * 8 days
    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(aliceLockdropTokenAmount, lockAmount1);
    assertEq(aliceLockPeriod, lockPeriod1);
    assertEq(lockdrop.totalAmount(), lockAmount1);
    assertEq(lockdrop.totalP88Weight(), lockAmount1 * lockPeriod1);

    // ------- Bob session -------
    uint256 lockAmount2 = 10 ether;
    uint256 lockPeriod2 = 10 days;

    vm.startPrank(BOB);
    mockERC20.mint(BOB, 30 ether);
    mockERC20.approve(address(lockdrop), 30 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 5 hours);
    lockdrop.lockToken(lockAmount2, lockPeriod2);
    (uint256 bobLockdropTokenAmount, uint256 bobLockPeriod, , ) = lockdrop
      .lockdropStates(BOB);
    vm.stopPrank();
    // After Bob lock the ERC20 token, the following criteria needs to satisfy:
    // 1. Balance of Bobs' ERC20 token should be 20
    // 2. The amount of Bobs' lockdrop token should be 10
    // 3. The number of lock period should be 10 days
    // 4. The total amount of lock token should be 16 + 10 = 26
    // 5. The total P88 weight should be 16 * 8 days + 10 * 10days
    assertEq(mockERC20.balanceOf(BOB), 20 ether);
    assertEq(bobLockdropTokenAmount, lockAmount2);
    assertEq(bobLockPeriod, lockPeriod2);
    assertEq(lockdrop.totalAmount(), lockAmount1 + lockAmount2);
    assertEq(
      lockdrop.totalP88Weight(),
      lockAmount1 * lockPeriod1 + lockAmount2 * lockPeriod2
    );
  }

  function testCorrectness_LockdropLockToken_Relock() external {
    uint256 lockAmount1 = 16 ether;
    uint256 lockPeriod1 = 8 days;
    uint256 lockAmount2 = 20 ether;
    uint256 lockPeriod2 = 40 days;

    // ------- Alice session -------
    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 100 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 4 hours);
    lockdrop.lockToken(lockAmount1, lockPeriod1);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);
    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(aliceLockdropTokenAmount, lockAmount1);
    assertEq(aliceLockPeriod, lockPeriod1);
    assertEq(lockdrop.totalAmount(), lockAmount1);
    assertEq(lockdrop.totalP88Weight(), lockAmount1 * lockPeriod1);

    lockdrop.earlyWithdrawLockedToken(lockAmount1, ALICE);

    lockdrop.lockToken(lockAmount2, lockPeriod2);
    (aliceLockdropTokenAmount, aliceLockPeriod, , ) = lockdrop.lockdropStates(
      ALICE
    );
    // After Alice withdraw all and relock, the following criteria needs to satisfy:
    // 1. Balance of Alice's ERC20 token should be 0
    // 2. The amount of Alice's lockdrop token should be 20
    // 3. The number of lock period should be 40 days
    // 4. The total amount of lock token should be 20
    // 5. The total P88 weight should be 20 * 40 days
    assertEq(mockERC20.balanceOf(ALICE), 0);
    assertEq(aliceLockdropTokenAmount, lockAmount2);
    assertEq(aliceLockPeriod, lockPeriod2);
    assertEq(lockdrop.totalAmount(), lockAmount2);
    assertEq(lockdrop.totalP88Weight(), lockAmount2 * lockPeriod2);
    vm.stopPrank();
  }

  function testCorrectness_LockdropAddLockAmount() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;
    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);
    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

    // Alice wants to lock more
    lockdrop.addLockAmount(4 ether);
    vm.stopPrank();

    (aliceLockdropTokenAmount, aliceLockPeriod, , ) = lockdrop.lockdropStates(
      ALICE
    );
    // After Alice add more ERC20 token, the following criteria needs to satisfy:
    // 1. Balance of Alice's ERC20 token should be 0
    // 2. The amount of Alice's lockdrop token should be 20
    // 3. The number of lock period should be 8 days
    // 4. The total amount of lock token should be 20
    // 5. The total P88 weight should be 20 * 8 days
    assertEq(mockERC20.balanceOf(ALICE), 0);
    assertEq(aliceLockdropTokenAmount, 20 ether);
    assertEq(aliceLockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), 20 ether);
    assertEq(lockdrop.totalP88Weight(), 20 ether * lockPeriod);
  }

  function testCorrectness_LockdropExtendLockPeriod() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    lockdrop.lockToken(lockAmount, lockPeriod);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);
    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);

    // Alice wants to extend her lock period
    lockdrop.extendLockPeriod(12 days);
    vm.stopPrank();
    (aliceLockdropTokenAmount, aliceLockPeriod, , ) = lockdrop.lockdropStates(
      ALICE
    );

    // After Alice extend her lock period, the following criteria needs to satisfy:
    // 1. Balance of Alice's ERC20 token should be 4
    // 2. The amount of Alice's lockdrop token should be 16
    // 3. The number of lock period should be 12 days
    // 4. The total amount of lock token should be 16
    // 5. The total P88 weight should be 16 * 12 days
    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, 12 days);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * 12 days);
  }

  function testCorrectness_LockdropLockTokenFor_GatewayCalled() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    // ------- Alice session -------
    vm.startPrank(lockdropConfig.gatewayAddress());
    vm.warp(lockdropConfig.startLockTimestamp() + 4 hours);
    // Assume that gateway already recieve token from Alice
    mockERC20.mint(lockdropConfig.gatewayAddress(), 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    lockdrop.lockTokenFor(lockAmount, lockPeriod, ALICE);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);
    vm.stopPrank();
    // After gateway lock Alice's ERC20 token, the following criteria needs to satisfy:
    // 1. The amount of Alice's lockdrop token should be 16
    // 2. The number of lock period should be 8 days
    // 3. The total amount of lock token should be 16
    // 4. The total P88 weight should be 16 * 8 days
    // 5. Gateway ERC20 should be 0
    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);
    assertEq(mock2ERC20.balanceOf(lockdropConfig.gatewayAddress()), 0);
  }

  function testCorrectness_LockdropLockTokenFor_GatewayCalledRelock() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    // ------- Alice session -------
    vm.startPrank(lockdropConfig.gatewayAddress());
    vm.warp(lockdropConfig.startLockTimestamp() + 4 hours);
    // Assume that gateway already recieve token from Alice
    mockERC20.mint(lockdropConfig.gatewayAddress(), 20 ether);
    mockERC20.approve(address(lockdrop), 100 ether);
    lockdrop.lockTokenFor(lockAmount, lockPeriod, ALICE);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);

    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);
    assertEq(mock2ERC20.balanceOf(lockdropConfig.gatewayAddress()), 0);

    lockdrop.earlyWithdrawLockedToken(lockAmount, ALICE);

    lockdrop.lockTokenFor(20 ether, 40 days, ALICE);
    (aliceLockdropTokenAmount, aliceLockPeriod, , ) = lockdrop.lockdropStates(
      ALICE
    );
    // After Alice withdraw all and call gateway to relock, the following criteria needs to satisfy:
    // 1. Balance of Alice's ERC20 token should be 0
    // 2. The amount of Alice's lockdrop token should be 20
    // 3. The number of lock period should be 40 days
    // 4. The total amount of lock token should be 20
    // 5. The total P88 weight should be 20 * 40 days
    assertEq(mockERC20.balanceOf(ALICE), 0);
    assertEq(aliceLockdropTokenAmount, 20 ether);
    assertEq(aliceLockPeriod, 40 days);
    assertEq(lockdrop.totalAmount(), 20 ether);
    assertEq(lockdrop.totalP88Weight(), 20 ether * 40 days);
    vm.stopPrank();
  }

  function testCorrectness_AddLockAmountFor_GatewayCalled() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    // ------- Alice session -------
    vm.startPrank(lockdropConfig.gatewayAddress());
    vm.warp(lockdropConfig.startLockTimestamp() + 4 hours);
    // Assume that gateway already recieve token from Alice
    mockERC20.mint(lockdropConfig.gatewayAddress(), 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    lockdrop.lockTokenFor(lockAmount, lockPeriod, ALICE);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);
    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);
    assertEq(mock2ERC20.balanceOf(lockdropConfig.gatewayAddress()), 0);

    // Alice wants to lock more, done by gateway
    lockdrop.addLockAmountFor(4 ether, ALICE);
    vm.stopPrank();

    (aliceLockdropTokenAmount, aliceLockPeriod, , ) = lockdrop.lockdropStates(
      ALICE
    );
    // After gateway lock more ERC20 token for Alice, the following criteria needs to satisfy:
    // 1. The amount of Alice's lockdrop token should be 20
    // 2. The number of lock period should be 8 days
    // 3. The total amount of lock token should be 20
    // 4. The total P88 weight should be 20 * 8 days
    assertEq(aliceLockdropTokenAmount, 20 ether);
    assertEq(aliceLockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), 20 ether);
    assertEq(lockdrop.totalP88Weight(), 20 ether * lockPeriod);
  }

  function testCorrectness_LockdropExtendLockPeriodFor_GatewayCalled()
    external
  {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    // ------- Alice session -------
    vm.startPrank(lockdropConfig.gatewayAddress());
    vm.warp(lockdropConfig.startLockTimestamp() + 4 hours);
    // Assume that gateway already recieve token from Alice
    mockERC20.mint(lockdropConfig.gatewayAddress(), 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    lockdrop.lockTokenFor(lockAmount, lockPeriod, ALICE);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);
    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);
    assertEq(mock2ERC20.balanceOf(lockdropConfig.gatewayAddress()), 0);

    // Alice wants to extend her lock period done by gateway
    lockdrop.extendLockPeriodFor(20 days, ALICE);
    vm.stopPrank();
    (aliceLockdropTokenAmount, aliceLockPeriod, , ) = lockdrop.lockdropStates(
      ALICE
    );

    // After gateway extend lock period for Alice, the following criteria needs to satisfy:
    // 1. The amount of Alice's lockdrop token should be 16
    // 2. The number of lock period should be 20 days
    // 3. The total amount of lock token should be 16
    // 4. The total P88 weight should be 16 * 20 days
    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, 20 days);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * 20 days);
  }

  function testRevert_LockdropLockToken_ExceedLockdropPeriod() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 7 days);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_NotInLockdropPeriod()"));
    lockdrop.lockToken(lockAmount, lockPeriod);
    vm.stopPrank();
  }

  function testRevert_LockdropLockToken_DepositZeroToken() external {
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_ZeroAmountNotAllowed()"));
    lockdrop.lockToken(0, lockPeriod);
    vm.stopPrank();
  }

  function testRevert_LockdropLockToken_LockPeriodLessThan7Days() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 2 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_InvalidLockPeriod()"));
    lockdrop.lockToken(lockAmount, lockPeriod);
    vm.stopPrank();
  }

  function testRevert_LockdropLockToken_LockPeriodMoreThan364Days() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 365 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_InvalidLockPeriod()"));
    lockdrop.lockToken(lockAmount, lockPeriod);
    vm.stopPrank();
  }

  function testRevert_LockdropLockTokenFor_NotGatewayCalled() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    vm.warp(lockdropConfig.startLockTimestamp() + 4 hours);
    mockERC20.mint(lockdropConfig.gatewayAddress(), 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_NotGateway()"));
    lockdrop.lockTokenFor(lockAmount, lockPeriod, ALICE);
    vm.stopPrank();
  }

  function testRevert_AddLockAmountFor_NotGatewayCalled() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    // ------- Alice session -------
    vm.startPrank(lockdropConfig.gatewayAddress());
    vm.warp(lockdropConfig.startLockTimestamp() + 4 hours);
    // Assume that gateway already recieve token from Alice
    mockERC20.mint(lockdropConfig.gatewayAddress(), 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    lockdrop.lockTokenFor(lockAmount, lockPeriod, ALICE);
    vm.stopPrank();
    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_NotGateway()"));
    lockdrop.addLockAmountFor(4 ether, ALICE);
    vm.stopPrank();
  }

  function testRevert_LockdropExtendLockPeriodFor_NotGatewayCalled() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    // ------- Alice session -------
    vm.startPrank(lockdropConfig.gatewayAddress());
    vm.warp(lockdropConfig.startLockTimestamp() + 4 hours);
    // Assume that gateway already recieve token from Alice
    mockERC20.mint(lockdropConfig.gatewayAddress(), 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    lockdrop.lockTokenFor(lockAmount, lockPeriod, ALICE);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);
    vm.stopPrank();
    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_NotGateway()"));
    lockdrop.extendLockPeriodFor(20 days, ALICE);
    vm.stopPrank();
  }
}
