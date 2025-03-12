// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./StargateBaseTest.t.sol";

contract StargateDepositTest is StargateBaseTest {

    function testCanDepositSmallAmount() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        assertApproxEqAbs(stargateYieldModule.getBalance(), SMALL_AMOUNT, 1);
        // lpToken balance equals zero because lp tokens are stacked
        assertEq(IERC20(stargateYieldModule.pool()).balanceOf(address(stargateYieldModule)), 0);
        assertEq(IERC20(stargateYieldModule.baseToken()).balanceOf(address(stargateYieldModule)), 0);
        assertEq(IERC20(stargateYieldModule.baseToken()).balanceOf(address(smartFarmooor)), 0);
    }

    function testCanDepositBigAmount() public {
        _deposit(address(smartFarmooor), BIG_AMOUNT);
        assertApproxEqAbs(stargateYieldModule.getBalance(), BIG_AMOUNT, 1);
        // lpToken balance equals zero because lp tokens are stacked
        assertEq(IERC20(stargateYieldModule.pool()).balanceOf(address(stargateYieldModule)), 0);
        assertEq(IERC20(stargateYieldModule.baseToken()).balanceOf(address(stargateYieldModule)), 0);
        assertEq(IERC20(stargateYieldModule.baseToken()).balanceOf(address(smartFarmooor)), 0);
    }

    function testStargateEatOneWeiOnDepositWithSmallAmount() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        assertApproxEqAbs(stargateYieldModule.getBalance(), SMALL_AMOUNT, 1);
    }

    function testStargateEatOneWeiOnDepositWithBigAmount() public {
        _deposit(address(smartFarmooor), BIG_AMOUNT);
        assertApproxEqAbs(stargateYieldModule.getBalance(), BIG_AMOUNT, 1);
    }

    function testStargateEatOneWeiOnDepositWithMassiveAmount() public {
        _deposit(address(smartFarmooor), BIG_AMOUNT * 100);
        assertApproxEqAbs(stargateYieldModule.getBalance(), BIG_AMOUNT * 100, 1);
    }

    function testStargateEatOneWeiPerDepositWithSmallAmount() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT / 5);
        _deposit(address(smartFarmooor), SMALL_AMOUNT / 5);
        _deposit(address(smartFarmooor), SMALL_AMOUNT / 5);
        _deposit(address(smartFarmooor), SMALL_AMOUNT / 5);
        _deposit(address(smartFarmooor), SMALL_AMOUNT / 5);
        assertApproxEqAbs(stargateYieldModule.getBalance(), SMALL_AMOUNT, 5);
    }

    function testStargateEatOneWeiPerDepositWithBigAmount() public {
        _deposit(address(smartFarmooor), BIG_AMOUNT / 5);
        _deposit(address(smartFarmooor), BIG_AMOUNT / 5);
        _deposit(address(smartFarmooor), BIG_AMOUNT / 5);
        _deposit(address(smartFarmooor), BIG_AMOUNT / 5);
        _deposit(address(smartFarmooor), BIG_AMOUNT / 5);
        assertApproxEqAbs(stargateYieldModule.getBalance(), BIG_AMOUNT, 5);
    }

    function testStargateEatOneWeiPerDepositWithMassiveAmount() public {
        _deposit(address(smartFarmooor), BIG_AMOUNT * 100 / 5);
        _deposit(address(smartFarmooor), BIG_AMOUNT * 100 / 5);
        _deposit(address(smartFarmooor), BIG_AMOUNT * 100 / 5);
        _deposit(address(smartFarmooor), BIG_AMOUNT * 100 / 5);
        _deposit(address(smartFarmooor), BIG_AMOUNT * 100 / 5);
        assertApproxEqAbs(stargateYieldModule.getBalance(), BIG_AMOUNT * 100, 5);
    }

    function testOnlySmartFarmooorCanDeposit() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);

        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert("BaseModule: only smart farmooor");
        stargateYieldModule.deposit(SMALL_AMOUNT);
    }

    function testOwnerCannotDeposit() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);

        vm.prank(OWNER);
        vm.expectRevert("BaseModule: only smart farmooor");
        stargateYieldModule.deposit(SMALL_AMOUNT);
    }

    function testManagerCannotDeposit() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);

        vm.prank(MANAGER);
        vm.expectRevert("BaseModule: only smart farmooor");
        stargateYieldModule.deposit(SMALL_AMOUNT);
    }

    function testDepositAmountCannotBeZero() public {
        vm.prank(address(smartFarmooor));
        vm.expectRevert("Stargate: deposit amount cannot be zero");
        stargateYieldModule.deposit(0);
    }

    function testDepositEmitEvent() public {
        deal(BASE_TOKEN, address(smartFarmooor), SMALL_AMOUNT);
        vm.startPrank(address(smartFarmooor));
        IERC20(BASE_TOKEN).approve(address(stargateYieldModule), SMALL_AMOUNT);
        vm.expectEmit(false, false, false, true);
        emit Deposit(stargateYieldModule.baseToken(), SMALL_AMOUNT);
        stargateYieldModule.deposit(SMALL_AMOUNT);
        vm.stopPrank();
    }
}
