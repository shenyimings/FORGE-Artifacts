// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Lockdrop_BaseTest, console } from "./Lockdrop_BaseTest.inte.t.sol";

contract Lockdrop_StakePLP is Lockdrop_BaseTest {
  function setUp() public override {
    super.setUp();
    usdcPriceFeed.setLatestAnswer(1 * 10**8);
  }

  function testCorrectness_WhenUserLockToken_ThenLockdropStakePLP_AndSuccessfullyGetPLPAmount()
    external
  {
    uint256 lockAmount_ALICE = 16 ether;
    uint256 lockPeriod_ALICE = 8 days;

    uint256 lockAmount_BOB = 29 ether;
    uint256 lockPeriod_BOB = 10 days;

    // ------- Alice session -------
    vm.startPrank(ALICE);

    // mint USDC for ALICE
    usdc.mint(ALICE, 20 ether);
    usdc.approve(address(lockdrop), 20 ether);

    // 1 day later
    vm.warp(1 days);

    // ALICE Lock 16 USDC for 8 days
    lockdrop.lockToken(lockAmount_ALICE, lockPeriod_ALICE);
    vm.stopPrank();
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);
    assertEq(usdc.balanceOf(ALICE), 4 ether);
    assertEq(alicelockdropTokenAmount, lockAmount_ALICE);
    assertEq(lockdrop.totalAmount(), lockAmount_ALICE);

    // ------- BOB session -------
    vm.startPrank(BOB);

    // mint USDC for BOB
    usdc.mint(BOB, 30 ether);
    usdc.approve(address(lockdrop), 30 ether);

    // 1 day later
    vm.warp(1 days);

    // BOB Lock 29 USDC for 10 days
    lockdrop.lockToken(lockAmount_BOB, lockPeriod_BOB);
    vm.stopPrank();
    (
      uint256 boblockdropTokenAmount,
      uint256 boblockPeriod,
      bool bobP88Claimed,

    ) = lockdrop.lockdropStates(BOB);
    assertEq(usdc.balanceOf(BOB), 1 ether);
    assertEq(boblockdropTokenAmount, lockAmount_BOB);
    assertEq(lockdrop.totalAmount(), lockAmount_ALICE + lockAmount_BOB);

    // Lockdrop contract should have total amount of token that Alice and Bob locked
    assertEq(
      usdc.balanceOf(address(lockdrop)),
      lockAmount_ALICE + lockAmount_BOB
    );

    // After the lockdrop period ends, owner can stake PLP
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);

    vm.startPrank(address(lockdrop));
    usdc.approve(address(poolDiamond), lockAmount_ALICE + lockAmount_BOB);
    plp.approve(address(plpStaking), type(uint256).max);
    vm.stopPrank();

    vm.startPrank(DAVE);
    lockdrop.stakePLP();
    vm.stopPrank();

    // After Owner stake PLP, the following criteria needs to satisfy:
    // 1. lockdrop totalPLPAmount should more than zero
    // 2. PLP from lockdrop shold stake on PLP staking contract
    assertGt(lockdrop.totalPLPAmount(), 0);
    assertEq(
      plp.balanceOf(address(lockdropConfig.plpStaking())),
      lockdrop.totalPLPAmount()
    );
  }

  function testRevert_WhenUserLockToken_ThenLockdropStakePLP_ButStakeMultipleTime()
    external
  {
    uint256 lockAmount_ALICE = 16 ether;
    uint256 lockPeriod_ALICE = 8 days;

    // ------- Alice session -------
    vm.startPrank(ALICE);

    // mint USDC for ALICE
    usdc.mint(ALICE, 20 ether);
    usdc.approve(address(lockdrop), 20 ether);

    // 1 day later
    vm.warp(1 days);

    // ALICE Lock 16 USDC for 8 days
    lockdrop.lockToken(lockAmount_ALICE, lockPeriod_ALICE);
    vm.stopPrank();
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);
    assertEq(usdc.balanceOf(ALICE), 4 ether);
    assertEq(alicelockdropTokenAmount, lockAmount_ALICE);
    assertEq(lockdrop.totalAmount(), lockAmount_ALICE);

    // After the lockdrop period ends, owner can stake PLP
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);

    vm.startPrank(address(lockdrop));
    usdc.approve(address(poolDiamond), lockAmount_ALICE);
    plp.approve(address(plpStaking), type(uint256).max);
    vm.stopPrank();

    vm.startPrank(DAVE);
    lockdrop.stakePLP();
    vm.stopPrank();

    // owner need to stake again

    // After Owner stake PLP multiple time, the following criteria needs to satisfy:
    // 1. Expect revert Lockdrop_PLPAlreadyStaked()

    vm.startPrank(DAVE);
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_PLPAlreadyStaked()"));
    lockdrop.stakePLP();
    vm.stopPrank();
  }
}
