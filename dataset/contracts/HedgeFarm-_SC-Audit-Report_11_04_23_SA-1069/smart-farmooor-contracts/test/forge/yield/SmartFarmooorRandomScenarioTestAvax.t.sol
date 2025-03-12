// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../script/Deployer.s.sol";
import "./SmartFarmooorBasicTestHelperAvax.t.sol";

contract SmartFarmooorRandomScenarioTestAvax is
    SmartFarmooorBasicTestHelperAvax
{
    using SafeERC20 for IERC20;

    function testShouldDepositAndWithdrawInSameBlock() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);
        withdrawHelper(ALICE, smartFarmooor.balanceOf(ALICE));

        assertApproxEqAbs(
            IERC20(smartFarmooor.baseToken()).balanceOf(ALICE),
            DEPOSIT_AMOUNT,
            2 * smartFarmooor.numberOfModules() * PRECISION
        );
        assertEq(smartFarmooor.balanceOf(ALICE), 0);
    }

    function testBobShouldNotBeAbleToSandwitchPanic() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);
        _waitAndHarvest();

        depositHelper(BOB, DEPOSIT_AMOUNT);

        vm.startPrank(address(timelock));
        smartFarmooor.panic();
        smartFarmooor.finishPanic();
        vm.stopPrank();

        withdrawHelper(BOB, smartFarmooor.balanceOf(BOB));
        assertLe(
            IERC20(smartFarmooor.baseToken()).balanceOf(BOB),
            DEPOSIT_AMOUNT
        );

        withdrawHelper(ALICE, smartFarmooor.balanceOf(ALICE));
        assertGt(
            IERC20(smartFarmooor.baseToken()).balanceOf(ALICE),
            DEPOSIT_AMOUNT
        );
    }

    //We are vulnerable to this attack if aum is with 18 decimals (DAI, sAVAX etc)
    function testAliceShouldNotBeAbleToSandwichBobAndStealFunds() public {
        vm.startPrank(ALICE);
        deal(BASE_TOKEN, ALICE, 2);
        IERC20(BASE_TOKEN).safeApprove(address(smartFarmooor), type(uint256).max);
        vm.expectRevert("SmartFarmooor: amount too small");
        smartFarmooor.deposit(2);
        deal(BASE_TOKEN, address(smartFarmooor), DEPOSIT_AMOUNT + 2);
        vm.stopPrank();

        depositHelper(BOB, DEPOSIT_AMOUNT);

        uint256 shares = smartFarmooor.balanceOf(ALICE);
        vm.prank(ALICE);
        vm.expectRevert("SmartFarmooor: withdraw can't be 0");
        smartFarmooor.withdraw(shares);

        withdrawHelper(BOB, smartFarmooor.balanceOf(BOB));
        assertEq(
            IERC20(smartFarmooor.baseToken()).balanceOf(ALICE),
            2
        );
        assertApproxEqAbs(
            IERC20(smartFarmooor.baseToken()).balanceOf(BOB),
            DEPOSIT_AMOUNT, PRECISION
        );
    }

    function testShouldDepositSetModuleWithdraw() public {
        (IYieldModule lastModule, uint256 allocationLastModule) = smartFarmooor
            .yieldOptions(smartFarmooor.numberOfModules() - 1);

        vm.startPrank(address(timelock));
        smartFarmooor.pause();
        smartFarmooor.removeModule(smartFarmooor.numberOfModules() - 1);
        uint256[] memory allocations = new uint256[](
            smartFarmooor.numberOfModules()
        );
        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (, uint256 allocation) = smartFarmooor.yieldOptions(i);
            allocations[i] = allocation;
        }
        allocations[
            smartFarmooor.numberOfModules() - 1
        ] += allocationLastModule;
        smartFarmooor.setModuleAllocation(allocations);
        smartFarmooor.unpause();
        vm.stopPrank();

        depositHelper(ALICE, DEPOSIT_AMOUNT);
        _waitAndHarvest();

        _moveBlock(5);

        vm.startPrank(address(timelock));
        smartFarmooor.panic();
        smartFarmooor.addModule(lastModule);
        allocations = new uint256[](smartFarmooor.numberOfModules());
        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (, uint256 allocation) = smartFarmooor.yieldOptions(i);
            allocations[i] = allocation;
        }
        allocations[
            smartFarmooor.numberOfModules() - 2
        ] -= allocationLastModule;
        allocations[
            smartFarmooor.numberOfModules() - 1
        ] += allocationLastModule;
        smartFarmooor.setModuleAllocation(allocations);
        smartFarmooor.finishPanic();
        vm.stopPrank();

        _moveBlock(5);

        depositHelper(BOB, DEPOSIT_AMOUNT);

        _waitAndHarvest();

        withdrawHelper(ALICE, smartFarmooor.balanceOf(ALICE) / 2);
        withdrawHelper(BOB, smartFarmooor.balanceOf(BOB) / 2);

        assertGt(
            IERC20(smartFarmooor.baseToken()).balanceOf(ALICE),
            DEPOSIT_AMOUNT / 2
        );
        assertGt(
            IERC20(smartFarmooor.baseToken()).balanceOf(BOB),
            DEPOSIT_AMOUNT / 2
        );
        assertGt(
            IERC20(smartFarmooor.baseToken()).balanceOf(ALICE),
            IERC20(smartFarmooor.baseToken()).balanceOf(BOB)
        );

        _waitAndHarvest();

        _moveBlock(5);

        withdrawHelper(ALICE, smartFarmooor.balanceOf(ALICE));
        withdrawHelper(BOB, smartFarmooor.balanceOf(BOB));

        assertEq(smartFarmooor.balanceOf(ALICE), 0);
        assertEq(smartFarmooor.balanceOf(BOB), 0);

        assertGt(
            IERC20(smartFarmooor.baseToken()).balanceOf(ALICE),
            DEPOSIT_AMOUNT
        );
        assertGt(
            IERC20(smartFarmooor.baseToken()).balanceOf(BOB),
            DEPOSIT_AMOUNT
        );
        assertGt(
            IERC20(smartFarmooor.baseToken()).balanceOf(ALICE),
            IERC20(smartFarmooor.baseToken()).balanceOf(BOB)
        );
    }

    function testAllocationShouldBeCorrectAfterHarvest() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);

        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (IYieldModule module, uint256 allocation) = smartFarmooor
                .yieldOptions(i);
            assertApproxEqAbs(
                module.getBalance(),
                (DEPOSIT_AMOUNT * allocation) / smartFarmooor.MAX_BPS(),
                smartFarmooor.numberOfModules() * PRECISION
            );
        }

        _moveBlock(10000000);

        uint256[] memory amounts = new uint256[](
            smartFarmooor.numberOfModules()
        );
        bool test = false;
        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (IYieldModule module, uint256 allocation) = smartFarmooor
                .yieldOptions(i);
            amounts[i] =
                (module.getBalance() * smartFarmooor.MAX_BPS()) /
                allocation;
            for (uint256 j = 0; j < i; j++) {
                if (amounts[j] > amounts[i]) {
                    // If imbalance we set test to true
                    if (amounts[j] - amounts[i] > 1000) {
                        test = true;
                    }
                } else {
                    if (amounts[i] - amounts[j] > 1000) {
                        test = true;
                    }
                }
            }
        }
        assertTrue(test);

        uint256 profit = smartFarmooor.harvest();

        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (IYieldModule module, uint256 allocation) = smartFarmooor
                .yieldOptions(i);
            assertApproxEqAbs(
                module.getBalance(),
                ((DEPOSIT_AMOUNT + profit) * allocation) /
                    smartFarmooor.MAX_BPS(),
                smartFarmooor.numberOfModules() * PRECISION
            );
        }
    }

    function testWhaleShouldWithdrawEvenWithShrimp() public {
        uint256 whaleAmount;
        // Needed to avoid reaching max cap on aave with 18 decimals token
        if (IERC20Metadata(smartFarmooor.baseToken()).decimals() == 18) {
            whaleAmount = DEPOSIT_AMOUNT;
        }
        if (IERC20Metadata(smartFarmooor.baseToken()).decimals() == 6) {
            whaleAmount = 1e11;
        } else {
            whaleAmount = BIG_DEPOSIT_AMOUNT;
        }
        uint256 bobAmount = SM_MIN_AMOUNT;

        //double cap of strat to deposit whaleAmount
        vm.prank(address(timelock));
        smartFarmooor.setCap(BIG_DEPOSIT_AMOUNT * 2);

        depositHelper(ALICE, whaleAmount);
        depositHelper(BOB, bobAmount);

        _moveBlock(10);
        uint profit = smartFarmooor.harvest();

        _moveBlock(1000000);

        deal(ALICE, 300000000000000000);
        uint shares = smartFarmooor.balanceOf(ALICE);
        vm.prank(ALICE);
        smartFarmooor.withdraw{value : 300000000000000000}(shares);
        uint aliceBalanceWithoutStargateFunds =  IERC20(BASE_TOKEN).balanceOf(ALICE);
        deal(BASE_TOKEN, ALICE, aliceBalanceWithoutStargateFunds + whaleAmount * STARGATE_ALLOCATION / MAX_BPS);
        withdrawHelper(BOB, smartFarmooor.balanceOf(BOB));

        assertEq(smartFarmooor.balanceOf(ALICE), 0);
        assertGt(IERC20(smartFarmooor.baseToken()).balanceOf(ALICE), whaleAmount);
        assertGt(IERC20(smartFarmooor.baseToken()).balanceOf(BOB), bobAmount);
    }

    function _waitAndHarvest() public {
        _moveBlock(10000);
        smartFarmooor.harvest();
    }

    function _addStargateAndSetAllocation() public {
        vm.startPrank(address(timelock));
        addStargateToSmartFarmooor(stargateYieldModule);
        uint256[] memory moduleAllocations = new uint256[](2);
        moduleAllocations[0] = smartFarmooor.MAX_BPS() / 2;
        moduleAllocations[1] = smartFarmooor.MAX_BPS() / 2;

        smartFarmooor.setModuleAllocation(moduleAllocations);
        vm.stopPrank();
    }
}
