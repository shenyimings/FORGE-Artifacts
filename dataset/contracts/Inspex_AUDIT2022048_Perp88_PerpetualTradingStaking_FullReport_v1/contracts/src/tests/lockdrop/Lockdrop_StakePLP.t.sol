// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Lockdrop_BaseTest, console } from "./Lockdrop_BaseTest.t.sol";

contract Lockdrop_StakePLP is Lockdrop_BaseTest {
  function setUp() public override {
    super.setUp();
    mockPLPToken.setMinter(address(this), true);
  }

  function testCorrectness_LockdropStakePLP_SuccessfullyGetPLPAmount()
    external
  {
    uint256 lockAmount1 = 16 ether;
    uint256 lockPeriod1 = 8 days;
    uint256 lockAmount2 = 29 ether;
    uint256 lockPeriod2 = 10 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(120000);
    lockdrop.lockToken(lockAmount1, lockPeriod1);
    vm.stopPrank();
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);
    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(alicelockdropTokenAmount, lockAmount1);
    assertEq(lockdrop.totalAmount(), lockAmount1);

    vm.startPrank(BOB);
    mockERC20.mint(BOB, 30 ether);
    mockERC20.approve(address(lockdrop), 30 ether);

    vm.warp(130000);
    lockdrop.lockToken(lockAmount2, lockPeriod2);
    vm.stopPrank();
    (
      uint256 boblockdropTokenAmount,
      uint256 boblockPeriod,
      bool bobP88Claimed,

    ) = lockdrop.lockdropStates(BOB);
    assertEq(mockERC20.balanceOf(BOB), 1 ether);
    assertEq(boblockdropTokenAmount, lockAmount2);
    assertEq(lockdrop.totalAmount(), lockAmount1 + lockAmount2);

    // Lockdrop contract should have total amount of token that Alice and Bob locked
    assertEq(mockERC20.balanceOf(address(lockdrop)), lockAmount1 + lockAmount2);

    // After the lockdrop period ends, owner can stake PLP
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);

    vm.startPrank(address(lockdrop));
    mockPLPToken.approve(address(lockdropConfig.plpStaking()), 100 ether);
    vm.stopPrank();

    vm.startPrank(address(this));
    // Owner mint PLPToken
    mockPLPToken.mint(address(this), 90 ether);
    mockPLPToken.approve(address(lockdropConfig.plpStaking()), 100 ether);
    assertEq(mockPLPToken.balanceOf(address(lockdropConfig.plpStaking())), 0);

    lockdrop.stakePLP();
    lockdropConfig.plpStaking().deposit(
      address(lockdrop),
      address(mockPLPToken),
      90 ether
    );
    assertEq(lockdrop.totalPLPAmount(), 90 ether);
    assertEq(
      mockPLPToken.balanceOf(address(lockdropConfig.plpStaking())),
      90 ether
    );
    assertEq(mockPLPToken.balanceOf(address(lockdrop)), 0);
    vm.stopPrank();
  }

  function testRevert_LockdropStakePLP_MultipleStakingNotAllow() external {
    uint256 lockAmount = 16 ether;
    uint256 lockPeriod = 8 days;

    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    vm.warp(120000);
    lockdrop.lockToken(lockAmount, lockPeriod);
    vm.stopPrank();
    (
      uint256 alicelockdropTokenAmount,
      uint256 alicelockPeriod,
      bool aliceP88Claimed,

    ) = lockdrop.lockdropStates(ALICE);
    assertEq(mockERC20.balanceOf(ALICE), 4 ether);
    assertEq(alicelockdropTokenAmount, lockAmount);
    assertEq(lockdrop.totalAmount(), lockAmount);

    // Lockdrop contract should have total amount of token that Alice and Bob locked
    assertEq(mockERC20.balanceOf(address(lockdrop)), lockAmount);

    // After the lockdrop period ends, owner can stake PLP
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);

    // Lockdrop approve strategy and PLPStaking
    vm.startPrank(address(lockdrop));
    mockPLPToken.approve(address(lockdropConfig.plpStaking()), 32 ether);
    vm.stopPrank();

    vm.startPrank(address(this));
    // Owner mint PLPToken
    mockPLPToken.mint(address(lockdrop), 32 ether);
    mockPLPToken.approve(address(lockdropConfig.plpStaking()), 32 ether);

    lockdrop.stakePLP();
    vm.expectRevert(abi.encodeWithSignature("Lockdrop_PLPAlreadyStaked()"));
    lockdrop.stakePLP();
    vm.stopPrank();
  }
}
