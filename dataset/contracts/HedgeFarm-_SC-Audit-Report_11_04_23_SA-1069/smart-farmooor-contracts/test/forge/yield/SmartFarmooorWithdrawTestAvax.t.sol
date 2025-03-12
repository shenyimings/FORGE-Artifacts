// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../script/Deployer.s.sol";
import "./SmartFarmooorBasicTestHelperAvax.t.sol";

contract SmartFarmooorWithdrawTestAvax is SmartFarmooorBasicTestHelperAvax {
    using SafeERC20 for IERC20;

    function testWithdrawAll() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);

        assertEq(IERC20(smartFarmooor.baseToken()).balanceOf(ALICE), 0);
        uint sharesBefore = smartFarmooor.balanceOf(ALICE);

        vm.prank(ALICE);
        smartFarmooor.withdraw(sharesBefore);
        uint sharesAfter = smartFarmooor.balanceOf(ALICE);

        assertEq(sharesAfter, 0);
        assertApproxEqAbs(IERC20(smartFarmooor.baseToken()).balanceOf(ALICE), DEPOSIT_AMOUNT, 2 * smartFarmooor.numberOfModules() * PRECISION);
        assertEq(IERC20(smartFarmooor.baseToken()).balanceOf(address(smartFarmooor)), 0);
        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (IYieldModule module,) = smartFarmooor.yieldOptions(i);
            assertEq(IERC20(smartFarmooor.baseToken()).balanceOf(address(module)), 0);
            assertApproxEqAbs(module.getBalance(), 0, smartFarmooor.numberOfModules() * PRECISION);
        }
    }


    function testWithdrawSome() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);

        assertEq(IERC20(smartFarmooor.baseToken()).balanceOf(ALICE), 0);
        uint sharesBefore = smartFarmooor.balanceOf(ALICE);

        vm.prank(ALICE);
        smartFarmooor.withdraw(sharesBefore / 2);
        uint sharesAfter = smartFarmooor.balanceOf(ALICE);

        assertEq(sharesAfter, sharesBefore / 2);
        assertApproxEqAbs(IERC20(smartFarmooor.baseToken()).balanceOf(ALICE), DEPOSIT_AMOUNT / 2, smartFarmooor.numberOfModules() * PRECISION);
    }

    function testWithdrawAfterSomeTime() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);
        assertEq(IERC20(smartFarmooor.baseToken()).balanceOf(ALICE), 0);

        _moveBlock(1000);
        smartFarmooor.harvest();

        _moveBlock(5);

        assertEq(IERC20(smartFarmooor.baseToken()).balanceOf(address(smartFarmooor)), 0);
        withdrawHelper(ALICE, smartFarmooor.balanceOf(ALICE));

        assertGt(IERC20(smartFarmooor.baseToken()).balanceOf(ALICE), DEPOSIT_AMOUNT);
    }

    function testMultipleWithdraw() public {
        // Scenario :
        //Alice deposit
        //Bob deposit
        //Harvest
        //Alice withdraw 50% of her shares
        //Harvest
        //Alice withdraw 100% of remaining shares

        depositHelper(ALICE, DEPOSIT_AMOUNT);

        _moveBlock(1000);
        depositHelper(BOB, DEPOSIT_AMOUNT);

        _moveBlock(1000);
        smartFarmooor.harvest();
        assertEq(IERC20(smartFarmooor.baseToken()).balanceOf(address(smartFarmooor)), 0);
        withdrawHelper(ALICE, smartFarmooor.balanceOf(ALICE) / 2);
        assertEq(smartFarmooor.balanceOf(ALICE), DEPOSIT_AMOUNT / 2);

        _moveBlock(1000);
        smartFarmooor.harvest();
        withdrawHelper(ALICE, smartFarmooor.balanceOf(ALICE));

        assertEq(smartFarmooor.balanceOf(ALICE), 0);
        assertGt(IERC20(BASE_TOKEN).balanceOf(ALICE), DEPOSIT_AMOUNT);
    }

    function testShouldEmitWithdrawEvent() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);

        _moveBlock(1000);
        smartFarmooor.harvest();
        uint sharesToWithdraw = smartFarmooor.balanceOf(ALICE);

        _moveBlock(1);

        vm.startPrank(ALICE);
                                            //can't test Amount field
        vm.expectEmit(false, false, false, false, address(smartFarmooor));
        emit Withdraw(ALICE, sharesToWithdraw, DEPOSIT_AMOUNT);
        smartFarmooor.withdraw(sharesToWithdraw);
        vm.stopPrank();
    }

    function testTotalSupplyShouldBeNullIfAllWithdraw() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);
        _moveBlock(1);
        depositHelper(BOB, DEPOSIT_AMOUNT);

        _moveBlock(1000);
        smartFarmooor.harvest();

        withdrawHelper(BOB, smartFarmooor.balanceOf(BOB));
        withdrawHelper(ALICE, smartFarmooor.balanceOf(ALICE));
        assertEq(smartFarmooor.totalSupply(), 0);
    }

    function testTotalSupplyShouldBeNullIfAllWithdrawWithPerfFee() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);
        _moveBlock(1);
        depositHelper(BOB, DEPOSIT_AMOUNT);

        vm.prank(address(timelock));
        uint16 perfFee = 10 * 100;
        //10% perf fee
        smartFarmooor.setPerformanceFee(perfFee);

        _moveBlock(1000);
        smartFarmooor.harvest();
        _moveBlock(1);

        withdrawHelper(BOB, smartFarmooor.balanceOf(BOB));
        withdrawHelper(ALICE, smartFarmooor.balanceOf(ALICE));
        assertEq(smartFarmooor.totalSupply(), 0);
    }

    function testShouldWithdrawAllWithMultipleModules() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);
        _moveBlock(10000);

        smartFarmooor.harvest();
        _moveBlock(1);

        // withdrawHelper(ALICE, SmartFarmooor.balanceOf(ALICE));
    }

    function testShouldWithdrawAllWithMultipleDeposits() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);
        _moveBlock(10000);
        smartFarmooor.harvest();

        _moveBlock(5);

        depositHelper(BOB, DEPOSIT_AMOUNT);
        _moveBlock(10000);
        smartFarmooor.harvest();

        _moveBlock(1);

        depositHelper(CLARA, DEPOSIT_AMOUNT);
        _moveBlock(10000);
        smartFarmooor.harvest();

        _moveBlock(1);

        //Alice again
        depositHelper(ALICE, DEPOSIT_AMOUNT);
        _moveBlock(10000);
        smartFarmooor.harvest();

        _moveBlock(1);

        withdrawHelper(ALICE, smartFarmooor.balanceOf(ALICE));
        withdrawHelper(BOB, smartFarmooor.balanceOf(BOB));
        withdrawHelper(CLARA, smartFarmooor.balanceOf(CLARA));
    }

    function testShouldFailOnBaseTokenRescueWithdrawal() public {
        deal(smartFarmooor.baseToken(), address(smartFarmooor), DEPOSIT_AMOUNT);
        _moveBlock(1);
        vm.startPrank(address(timelock));
        vm.expectRevert(bytes("SmartFarmooor: can't pull out base tokens"));
        smartFarmooor.rescueToken(BASE_TOKEN);
        vm.stopPrank();
    }

    function testShouldAllowTokenRescueWithdrawal() public {
        deal(QI, address(smartFarmooor), DEPOSIT_AMOUNT);
        _moveBlock(1);
        assertEq(IERC20(QI).balanceOf(address(timelock)), 0);
        vm.startPrank(address(timelock));
        smartFarmooor.rescueToken(QI);
        assertEq(IERC20(QI).balanceOf(address(timelock)), DEPOSIT_AMOUNT);
        vm.stopPrank();
    }
}
