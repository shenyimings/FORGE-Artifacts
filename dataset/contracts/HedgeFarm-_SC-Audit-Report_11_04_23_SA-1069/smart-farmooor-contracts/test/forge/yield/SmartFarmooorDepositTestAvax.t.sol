 // SPDX-License-Identifier: MIT
 pragma solidity ^0.8.0;

 import "./SmartFarmooorBasicTestHelperAvax.t.sol";

 contract SmartFarmooorDepositTestAvax is SmartFarmooorBasicTestHelperAvax {
     using SafeERC20 for IERC20;

     function testDeposit() public {
         depositHelper(ALICE, DEPOSIT_AMOUNT);
         assertEq(IERC20(BASE_TOKEN).balanceOf(ALICE), 0);
         assertEq(smartFarmooor.balanceOf(ALICE), DEPOSIT_AMOUNT);
     }

     function testShouldNotDepositLessThanMinAmount() public {
         vm.startPrank(ALICE);
         IERC20(smartFarmooor.baseToken()).safeApprove(address(smartFarmooor), type(uint256).max);
         vm.expectRevert(bytes("SmartFarmooor: amount too small"));
         smartFarmooor.deposit(0);
         vm.stopPrank();
     }

     function testShouldEmitEvent() public {
         vm.startPrank(ALICE);
         deal(BASE_TOKEN, ALICE, DEPOSIT_AMOUNT);
         IERC20(smartFarmooor.baseToken()).safeApprove(address(smartFarmooor), type(uint256).max);

         vm.expectEmit(false, false, false, true, address(smartFarmooor));
         emit Deposit(ALICE, DEPOSIT_AMOUNT);
         smartFarmooor.deposit(DEPOSIT_AMOUNT);

         vm.stopPrank();
     }

     function testShouldHaveShares() public {
         depositHelper(ALICE, DEPOSIT_AMOUNT);
         assertEq(smartFarmooor.balanceOf(ALICE), DEPOSIT_AMOUNT);
     }

     function testShouldHaveEqualSharesAtStart() public {
         depositHelper(ALICE, DEPOSIT_AMOUNT);
         depositHelper(BOB, DEPOSIT_AMOUNT);

         assertApproxEqAbs(smartFarmooor.balanceOf(ALICE), smartFarmooor.balanceOf(BOB), smartFarmooor.numberOfModules() * PRECISION);
     }

     function testShouldHaveFundsAccordingToAllocation() public {
         depositHelper(ALICE, DEPOSIT_AMOUNT);

         for (uint i = 0; i < smartFarmooor.numberOfModules(); i++) {
             (IYieldModule module, uint allocation) = smartFarmooor.yieldOptions(i);
             uint fundsInThisModule = DEPOSIT_AMOUNT * allocation / smartFarmooor.MAX_BPS();
             assertApproxEqAbs(fundsInThisModule, module.getBalance(), smartFarmooor.numberOfModules() * PRECISION);
         }
     }

     function testShouldHarvestOnDepositWhenTotalSupply() public {
         depositHelper(ALICE, DEPOSIT_AMOUNT);

         vm.startPrank(BOB);
         deal(BASE_TOKEN, BOB, DEPOSIT_AMOUNT);
         IERC20(smartFarmooor.baseToken()).safeApprove(address(smartFarmooor), type(uint256).max);

         vm.expectEmit(false, false, false, false);
         emit Harvest(0);
         smartFarmooor.deposit(DEPOSIT_AMOUNT);

         vm.stopPrank();
     }

     function testCannotDepositWhenPaused() public {
         vm.prank(address(timelock));
         smartFarmooor.pause();

         vm.startPrank(BOB);
         deal(BASE_TOKEN, BOB, DEPOSIT_AMOUNT);
         IERC20(smartFarmooor.baseToken()).safeApprove(address(smartFarmooor), type(uint256).max);
         vm.expectRevert(bytes("Pausable: paused"));
         smartFarmooor.deposit(DEPOSIT_AMOUNT);

         vm.stopPrank();
     }

     function testCanDepositAfterUnpause() public {
         testCannotDepositWhenPaused();

         vm.prank(address(timelock));
         smartFarmooor.unpause();

         vm.prank(BOB);
         smartFarmooor.deposit(DEPOSIT_AMOUNT);

         assertEq(smartFarmooor.balanceOf(BOB), DEPOSIT_AMOUNT);
     }
 }
