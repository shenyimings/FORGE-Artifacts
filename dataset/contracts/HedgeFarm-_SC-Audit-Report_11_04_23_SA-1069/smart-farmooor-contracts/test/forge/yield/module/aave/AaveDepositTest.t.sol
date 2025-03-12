// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AaveBaseTest.t.sol";

contract AaveDepositTest is AaveBaseTest {

    function testCanDeposit() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        assertEq(aaveYieldModule.getBalance(), SMALL_AMOUNT);
        assertEq(IERC20(aaveYieldModule.baseToken()).balanceOf(address(aaveYieldModule)), 0);
        assertEq(IERC20(aaveYieldModule.baseToken()).balanceOf(address(smartFarmooor)), 0);
    }

    function testOnlySmartFarmooorCanDeposit() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);

        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert("BaseModule: only smart farmooor");
        aaveYieldModule.deposit(SMALL_AMOUNT);
    }

    function testOwnerCannotDeposit() public {
        vm.prank(OWNER);
        vm.expectRevert("BaseModule: only smart farmooor");
        aaveYieldModule.deposit(SMALL_AMOUNT);
    }

    function testManagerCannotDeposit() public {
        vm.prank(MANAGER);
        vm.expectRevert("BaseModule: only smart farmooor");
        aaveYieldModule.deposit(SMALL_AMOUNT);
    }

    function testDepositEmitEvent() public {
        deal(aaveYieldModule.baseToken(), address(smartFarmooor), SMALL_AMOUNT);
        vm.startPrank(address(smartFarmooor));
        IERC20(aaveYieldModule.baseToken()).approve(address(aaveYieldModule), SMALL_AMOUNT);
        vm.expectEmit(false, false, false, true);
        emit Deposit(aaveYieldModule.baseToken(), SMALL_AMOUNT);
        aaveYieldModule.deposit(SMALL_AMOUNT);
        vm.stopPrank();
    }
}
