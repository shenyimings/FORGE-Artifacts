// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Lockdrop_BaseTest } from "./Lockdrop_BaseTest.inte.t.sol";

contract Lockdrop_LockToken is Lockdrop_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_WhenUserLockToken() external {
    uint256 lockAmount_ALICE = 1 ether;
    uint256 lockPeriod_ALICE = 8 days;

    uint256 lockAmount_BOB = 4 ether;
    uint256 lockPeriod_BOB = 10 days;

    // ------- Alice session -------
    vm.startPrank(ALICE);

    // mint USDC for ALICE
    usdc.mint(ALICE, 2 ether);
    usdc.approve(address(lockdrop), 2 ether);

    // 4 hr after locktime begin
    vm.warp(lockdropConfig.startLockTimestamp() + 4 hours);

    //  ALICE lock 1 USDC for 8 days
    lockdrop.lockToken(lockAmount_ALICE, lockPeriod_ALICE);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);
    vm.stopPrank();

    // After ALICE lock the USDC token, the following criteria needs to satisfy:
    // 1. ALICE should remain 1 USDC
    // 2. Lockdrop define that ALICE has lock 1 USDC
    // 3. Lockdrop define that ALICE lock USDC for 8 days
    // 4. total lock USDC in lockdrop is 1 USDC
    // 5. The total P88 weight of ALICE should be 1 USDC * 8 days
    assertEq(usdc.balanceOf(ALICE), 1 ether);
    assertEq(aliceLockdropTokenAmount, 1 ether);
    assertEq(aliceLockPeriod, 8 days);
    assertEq(lockdrop.totalAmount(), 1 ether);
    assertEq(lockdrop.totalP88Weight(), lockAmount_ALICE * lockPeriod_ALICE);

    // ------- Bob session -------
    vm.startPrank(BOB);
    // mint USDC for BOB
    usdc.mint(BOB, 5 ether);
    usdc.approve(address(lockdrop), 4 ether);

    // 5 hr after locktime begin
    vm.warp(lockdropConfig.startLockTimestamp() + 5 hours);

    //  ALICE lock 2 USDC for 10 days
    lockdrop.lockToken(lockAmount_BOB, lockPeriod_BOB);
    (uint256 bobLockdropTokenAmount, uint256 bobLockPeriod, , ) = lockdrop
      .lockdropStates(BOB);
    vm.stopPrank();
    // After Bob lock the USDC token, the following criteria needs to satisfy:
    // 1. Balance of Bobs' USDC token should be 1
    // 2. The amount of Bobs' lockdrop token should be 4
    // 3. The number of lock period should be 10 days
    // 4. The total amount of lock token should be 1 + 2 = 3
    // 5. The total P88 weight should be 1 USDC * 8 days + 3 USDC * 10days
    assertEq(usdc.balanceOf(BOB), 1 ether);
    assertEq(bobLockdropTokenAmount, lockAmount_BOB);
    assertEq(bobLockPeriod, lockPeriod_BOB);
    assertEq(lockdrop.totalAmount(), lockAmount_ALICE + lockAmount_BOB);
    assertEq(
      lockdrop.totalP88Weight(),
      lockAmount_ALICE * lockPeriod_ALICE + lockAmount_BOB * lockPeriod_BOB
    );
  }

  function testCorrectness_WhenUserLockToken_ThenUserEarlyWithdraw_AndLockTokenAgain()
    external
  {
    uint256 lockAmount_ALICE_1 = 16 ether;
    uint256 lockPeriod_ALICE_1 = 8 days;
    uint256 lockAmount_ALICE_2 = 20 ether;
    uint256 lockPeriod_ALICE_2 = 40 days;

    // ------- Alice session -------
    vm.startPrank(ALICE);

    //  mint USDC for ALICE
    usdc.mint(ALICE, 20 ether);
    usdc.approve(address(lockdrop), 100 ether);

    // 4 hr after locktime begin
    vm.warp(lockdropConfig.startLockTimestamp() + 4 hours);

    // ALICE need to lock 16 USDC for  8 days
    lockdrop.lockToken(lockAmount_ALICE_1, lockPeriod_ALICE_1);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);

    assertEq(usdc.balanceOf(ALICE), 4 ether);
    assertEq(aliceLockdropTokenAmount, lockAmount_ALICE_1);
    assertEq(aliceLockPeriod, lockPeriod_ALICE_1);
    assertEq(lockdrop.totalAmount(), lockAmount_ALICE_1);
    assertEq(
      lockdrop.totalP88Weight(),
      lockAmount_ALICE_1 * lockPeriod_ALICE_1
    );

    //  ALICE early withdraw locked tokens immidiatly
    lockdrop.earlyWithdrawLockedToken(lockAmount_ALICE_1, ALICE);

    // ALICE lock again for 20 USDC for 40 days
    lockdrop.lockToken(lockAmount_ALICE_2, lockPeriod_ALICE_2);
    (aliceLockdropTokenAmount, aliceLockPeriod, , ) = lockdrop.lockdropStates(
      ALICE
    );
    // After Alice withdraw all and relock, the following criteria needs to satisfy:
    // 1. Balance of Alice's USDC token should be 0
    // 2. The amount of Alice's lockdrop token should be 20
    // 3. The number of lock period should be 40 days
    // 4. The total amount of lock token should be 20
    // 5. The total P88 weight should be 20 * 40 days
    assertEq(usdc.balanceOf(ALICE), 0);
    assertEq(aliceLockdropTokenAmount, lockAmount_ALICE_2);
    assertEq(aliceLockPeriod, lockPeriod_ALICE_2);
    assertEq(lockdrop.totalAmount(), lockAmount_ALICE_2);
    assertEq(
      lockdrop.totalP88Weight(),
      lockAmount_ALICE_2 * lockPeriod_ALICE_2
    );
    vm.stopPrank();
  }

  function testCorrectness_WhenUserLockToken_ThenLockMoreToken() external {
    uint256 lockAmount_ALICE = 16 ether;
    uint256 lockMoreAmount_ALICE = 4 ether;
    uint256 lockPeriod_ALICE = 8 days;

    // ------- Alice session -------
    vm.startPrank(ALICE);

    // mint USDC for ALICE
    usdc.mint(ALICE, 20 ether);
    usdc.approve(address(lockdrop), 20 ether);

    // 3 hr after locktime begin
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);

    // ALICE lock 16 USDC for 8 days
    lockdrop.lockToken(lockAmount_ALICE, lockPeriod_ALICE);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);

    assertEq(usdc.balanceOf(ALICE), 4 ether);
    assertEq(aliceLockdropTokenAmount, lockAmount_ALICE);
    assertEq(aliceLockPeriod, lockPeriod_ALICE);
    assertEq(lockdrop.totalAmount(), lockAmount_ALICE);
    assertEq(lockdrop.totalP88Weight(), lockAmount_ALICE * lockPeriod_ALICE);

    // Alice wants to lock more 4 USDC
    lockdrop.addLockAmount(lockMoreAmount_ALICE);
    vm.stopPrank();

    (aliceLockdropTokenAmount, aliceLockPeriod, , ) = lockdrop.lockdropStates(
      ALICE
    );
    // After Alice add more USDC token, the following criteria needs to satisfy:
    // 1. Balance of Alice's USDC token should be 0
    // 2. The amount of Alice's lockdrop token should be 20
    // 3. The number of lock period should be 8 days
    // 4. The total amount of lock token should be 20
    // 5. The total P88 weight should be 20 * 8 days
    assertEq(usdc.balanceOf(ALICE), 0);
    assertEq(aliceLockdropTokenAmount, 20 ether);
    assertEq(aliceLockPeriod, lockPeriod_ALICE);
    assertEq(lockdrop.totalAmount(), 20 ether);
    assertEq(lockdrop.totalP88Weight(), 20 ether * lockPeriod_ALICE);
  }

  function testCorrectness_WhenUserLockToken_ThenExtendLockPeriod() external {
    uint256 lockAmount_ALICE = 16 ether;
    uint256 lockPeriod_ALICE = 8 days;
    uint256 extendLockPeriod_ALICE = 12 days;

    // ------- Alice session -------
    vm.startPrank(ALICE);
    // mint USDC for ALICE
    usdc.mint(ALICE, 20 ether);
    usdc.approve(address(lockdrop), 20 ether);

    // 3 hr after locktime begin
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);

    // ALICE lock 16 USDC for 8 days
    lockdrop.lockToken(lockAmount_ALICE, lockPeriod_ALICE);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);
    assertEq(usdc.balanceOf(ALICE), 4 ether);
    assertEq(aliceLockdropTokenAmount, lockAmount_ALICE);
    assertEq(aliceLockPeriod, lockPeriod_ALICE);
    assertEq(lockdrop.totalAmount(), lockAmount_ALICE);
    assertEq(lockdrop.totalP88Weight(), lockAmount_ALICE * lockPeriod_ALICE);

    // Alice wants to extend her lock period to be 12 days
    lockdrop.extendLockPeriod(extendLockPeriod_ALICE);
    vm.stopPrank();
    (aliceLockdropTokenAmount, aliceLockPeriod, , ) = lockdrop.lockdropStates(
      ALICE
    );

    // After Alice extend her lock period, the following criteria needs to satisfy:
    // 1. Balance of Alice's USDC token should be 4
    // 2. The amount of Alice's lockdrop token should be 16
    // 3. The number of lock period should be 12 days
    // 4. The total amount of lock token should be 16
    // 5. The total P88 weight should be 16 * 12 days
    assertEq(usdc.balanceOf(ALICE), 4 ether);
    assertEq(aliceLockdropTokenAmount, lockAmount_ALICE);
    assertEq(aliceLockPeriod, 12 days);
    assertEq(lockdrop.totalAmount(), lockAmount_ALICE);
    assertEq(
      lockdrop.totalP88Weight(),
      lockAmount_ALICE * extendLockPeriod_ALICE
    );
  }

  function testCorrectness_LockdropLockTokenFor_WhenGatewayCalled() external {
    uint256 lockAmount = 20 ether;
    uint256 lockPeriod = 8 days;

    // ------- Alice session -------
    // Assume that gateway already recieve token from Alice

    vm.startPrank(lockdropConfig.gatewayAddress());

    // 4 hr after locktime begin
    vm.warp(lockdropConfig.startLockTimestamp() + 4 hours);

    // mint USDC for Lockdrop Gateway
    usdc.mint(lockdropConfig.gatewayAddress(), 20 ether);
    usdc.approve(address(lockdrop), 20 ether);

    // Gateway lock 20 USDC for 8 days
    lockdrop.lockTokenFor(lockAmount, lockPeriod, ALICE);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);

    vm.stopPrank();
    // After gateway lock Alice's USDC token, the following criteria needs to satisfy:
    // 1. The amount of Alice's lockdrop token should be 16
    // 2. The number of lock period should be 8 days
    // 3. The total amount of lock token should be 16
    // 4. The total P88 weight should be 16 * 8 days
    // 5. Gateway USDC should be 0
    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);
    assertEq(usdc.balanceOf(lockdropConfig.gatewayAddress()), 0);
  }

  function testCorrectness_LockAmountFor_AfterEarlyWithdraw_WhenGatewayCalled()
    external
  {
    uint256 lockAmount = 20 ether;
    uint256 lockPeriod = 8 days;

    // ------- Alice session -------
    // Assume that gateway already recieve token from Alice
    vm.startPrank(lockdropConfig.gatewayAddress());
    // 4 hr after locktime begin
    vm.warp(lockdropConfig.startLockTimestamp() + 4 hours);

    // mint USDC for Lockdrop gateway
    usdc.mint(lockdropConfig.gatewayAddress(), 20 ether);
    usdc.approve(address(lockdrop), 100 ether);

    // Gateway lock 20 USDC for 8 days
    lockdrop.lockTokenFor(lockAmount, lockPeriod, ALICE);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);

    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);
    assertEq(usdc.balanceOf(lockdropConfig.gatewayAddress()), 0);

    // ALICE early withdraw immidiatly
    lockdrop.earlyWithdrawLockedToken(lockAmount, ALICE);

    // ALICE lock 20 USDC again for 40 day by gateway
    lockdrop.lockTokenFor(20 ether, 40 days, ALICE);
    (aliceLockdropTokenAmount, aliceLockPeriod, , ) = lockdrop.lockdropStates(
      ALICE
    );

    // After Alice withdraw all and call gateway to relock, the following criteria needs to satisfy:
    // 1. Balance of Alice's USDC token should be 0
    // 2. The amount of Alice's lockdrop token should be 20
    // 3. The number of lock period should be 40 days
    // 4. The total amount of lock token should be 20
    // 5. The total P88 weight should be 20 * 40 days
    assertEq(usdc.balanceOf(ALICE), 0);
    assertEq(aliceLockdropTokenAmount, 20 ether);
    assertEq(aliceLockPeriod, 40 days);
    assertEq(lockdrop.totalAmount(), 20 ether);
    assertEq(lockdrop.totalP88Weight(), 20 ether * 40 days);
    vm.stopPrank();
  }

  function testCorrectness_AddMoreLockAmountFor_WhenGatewayCalled() external {
    uint256 lockAmount = 20 ether;
    uint256 lockPeriod = 8 days;
    uint256 lockMoreAmount = 4 ether;

    // ------- Alice session -------
    // Assume that gateway already recieve token from Alice
    vm.startPrank(lockdropConfig.gatewayAddress());
    vm.warp(lockdropConfig.startLockTimestamp() + 4 hours);

    usdc.mint(lockdropConfig.gatewayAddress(), 20 ether);
    usdc.approve(address(lockdrop), 20 ether);

    lockdrop.lockTokenFor(lockAmount, lockPeriod, ALICE);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);
    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);
    assertEq(usdc.balanceOf(lockdropConfig.gatewayAddress()), 0);

    usdc.mint(lockdropConfig.gatewayAddress(), lockMoreAmount);
    usdc.approve(address(lockdrop), lockMoreAmount);

    // Alice wants to lock more USDC, done by gateway
    lockdrop.addLockAmountFor(lockMoreAmount, ALICE);
    vm.stopPrank();

    (aliceLockdropTokenAmount, aliceLockPeriod, , ) = lockdrop.lockdropStates(
      ALICE
    );
    // After gateway lock more USDC token for Alice, the following criteria needs to satisfy:
    // 1. The amount of Alice's lockdrop token should be 20
    // 2. The number of lock period should be 8 days
    // 3. The total amount of lock token should be 20
    // 4. The total P88 weight should be 20 * 8 days
    assertEq(aliceLockdropTokenAmount, 24 ether);
    assertEq(aliceLockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), 24 ether);
    assertEq(lockdrop.totalP88Weight(), 24 ether * lockPeriod);
  }

  function testCorrectness_LockdropExtendLockPeriodFor_WhenGatewayCalled()
    external
  {
    uint256 lockAmount = 20 ether;
    uint256 lockPeriod = 8 days;
    uint256 extendLockPeriod = 20 days;

    // ------- Alice session -------
    // Assume that gateway already recieve token from Alice
    vm.startPrank(lockdropConfig.gatewayAddress());
    vm.warp(lockdropConfig.startLockTimestamp() + 4 hours);

    usdc.mint(lockdropConfig.gatewayAddress(), 20 ether);
    usdc.approve(address(lockdrop), 20 ether);

    lockdrop.lockTokenFor(lockAmount, lockPeriod, ALICE);
    (uint256 aliceLockdropTokenAmount, uint256 aliceLockPeriod, , ) = lockdrop
      .lockdropStates(ALICE);

    assertEq(aliceLockdropTokenAmount, lockAmount);
    assertEq(aliceLockPeriod, lockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * lockPeriod);
    assertEq(usdc.balanceOf(lockdropConfig.gatewayAddress()), 0);

    // Alice wants to extend her lock period done by gateway
    lockdrop.extendLockPeriodFor(extendLockPeriod, ALICE);
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
    assertEq(aliceLockPeriod, extendLockPeriod);
    assertEq(lockdrop.totalAmount(), lockAmount);
    assertEq(lockdrop.totalP88Weight(), lockAmount * extendLockPeriod);
  }

  function testRevert_UserLockToken_ButExceedLockdropPeriod() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    usdc.mint(ALICE, 20 ether);
    usdc.approve(address(lockdrop), 20 ether);

    // Lockdrop peroid is 1 days

    vm.warp(lockdropConfig.startLockTimestamp() + 7 days);

    vm.expectRevert(abi.encodeWithSignature("Lockdrop_NotInLockdropPeriod()"));
    lockdrop.lockToken(lockAmount, lockPeriod);
    vm.stopPrank();
  }

  function testRevert_UserLockToken_ButDepositZeroToken() external {
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    usdc.mint(ALICE, 20 ether);
    usdc.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_ZeroAmountNotAllowed()"));

    // Lock no token amount
    lockdrop.lockToken(0, lockPeriod);
    vm.stopPrank();
  }

  function testRevert_UserLockToken_ButLockPeriodLessThan7Days() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 2 days;

    vm.startPrank(ALICE);
    usdc.mint(ALICE, 20 ether);
    usdc.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_InvalidLockPeriod()"));
    lockdrop.lockToken(lockAmount, lockPeriod);
    vm.stopPrank();
  }

  function testRevert_UserLockToken_ButLockPeriodMoreThan364Days() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 365 days;

    vm.startPrank(ALICE);
    usdc.mint(ALICE, 20 ether);
    usdc.approve(address(lockdrop), 20 ether);
    vm.warp(lockdropConfig.startLockTimestamp() + 3 hours);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_InvalidLockPeriod()"));
    lockdrop.lockToken(lockAmount, lockPeriod);
    vm.stopPrank();
  }

  function testRevert_UserLockTokenForViaGateway_ButNotGatewayCalled()
    external
  {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    vm.warp(lockdropConfig.startLockTimestamp() + 4 hours);
    usdc.mint(lockdropConfig.gatewayAddress(), 20 ether);
    usdc.approve(address(lockdrop), 20 ether);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_NotGateway()"));
    lockdrop.lockTokenFor(lockAmount, lockPeriod, ALICE);
    vm.stopPrank();
  }

  function testRevert_UserAddMoreLockAmountForViaGateway_ButNotGatewayCalled()
    external
  {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    // ------- Alice session -------
    vm.startPrank(lockdropConfig.gatewayAddress());
    vm.warp(lockdropConfig.startLockTimestamp() + 4 hours);
    // Assume that gateway already recieve token from Alice
    usdc.mint(lockdropConfig.gatewayAddress(), 20 ether);
    usdc.approve(address(lockdrop), 20 ether);
    lockdrop.lockTokenFor(lockAmount, lockPeriod, ALICE);
    vm.stopPrank();
    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_NotGateway()"));
    lockdrop.addLockAmountFor(4 ether, ALICE);
    vm.stopPrank();
  }

  function testRevert_UserExtendLockPeriodForViaGateway_ButNotGatewayCalled()
    external
  {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    // ------- Alice session -------
    vm.startPrank(lockdropConfig.gatewayAddress());
    vm.warp(lockdropConfig.startLockTimestamp() + 4 hours);

    // Assume that gateway already recieve token from Alice
    usdc.mint(lockdropConfig.gatewayAddress(), 20 ether);
    usdc.approve(address(lockdrop), 20 ether);

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
