// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CompoundV2BaseTest.t.sol";

contract CompoundV2DepositTest is CompoundV2BaseTest {

    function testCanDeposit() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);

        assertApproxEqAbs(yieldModule.getBalance(), SMALL_AMOUNT, PRECISION);
        assertEq(IERC20(yieldModule.baseToken()).balanceOf(address(yieldModule)), 0);
        assertEq(IERC20(yieldModule.baseToken()).balanceOf(address(smartFarmooor)), 0);
    }

    function testCanDepositNative() public {
        BASE_TOKEN = WAVAX;
        BENQI_TOKEN = BENQI_AVAX;
        PRECISION = 10**9;
        deployBenqiYieldModule(address(smartFarmooor), address(dex));
        yieldModule = benqiYieldModule;

        deal(WAVAX, address(smartFarmooor), SMALL_AMOUNT);
        vm.startPrank(address(smartFarmooor));
        IERC20(yieldModule.baseToken()).approve(address(yieldModule), SMALL_AMOUNT);
        yieldModule.deposit(SMALL_AMOUNT);
        vm.stopPrank();

        assertApproxEqAbs(yieldModule.getBalance(), SMALL_AMOUNT, PRECISION);
        assertEq(IERC20(yieldModule.baseToken()).balanceOf(address(yieldModule)), 0);
        assertEq(IERC20(yieldModule.baseToken()).balanceOf(address(smartFarmooor)), 0);
    }

    function testOnlySmartFarmooorCanDeposit() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);

        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert("BaseModule: only smart farmooor");
        yieldModule.deposit(SMALL_AMOUNT);
    }

    function testOwnerCannotDeposit() public {
        vm.prank(OWNER);
        vm.expectRevert("BaseModule: only smart farmooor");
        yieldModule.deposit(SMALL_AMOUNT);
    }

    function testManagerCannotDeposit() public {
        vm.prank(MANAGER);
        vm.expectRevert("BaseModule: only smart farmooor");
        yieldModule.deposit(SMALL_AMOUNT);
    }

    function testDepositAmountCannotBeZero() public {
        vm.prank(address(smartFarmooor));
        vm.expectRevert("CompoundV2: deposit amount cannot be zero");
        yieldModule.deposit(0);
    }

    function testDepositEmitEvent() public {
        deal(yieldModule.baseToken(), address(smartFarmooor), SMALL_AMOUNT);
        vm.startPrank(address(smartFarmooor));
        IERC20(yieldModule.baseToken()).approve(address(yieldModule), SMALL_AMOUNT);
        vm.expectEmit(false, false, false, true);
        emit Deposit(yieldModule.baseToken(), SMALL_AMOUNT);
        yieldModule.deposit(SMALL_AMOUNT);
        vm.stopPrank();
    }
}
