// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AaveBaseTest.t.sol";

contract AaveWithdrawTest is AaveBaseTest {

    function testCanWithdraw() public {
        uint256 shareFraction = SMALL_AMOUNT * 1e18 / BIG_AMOUNT;
        _deposit(address(smartFarmooor), BIG_AMOUNT);
        _withdraw(address(smartFarmooor), shareFraction, ALICE);
        
        assertApproxEqAbs(aaveYieldModule.getBalance(), BIG_AMOUNT - SMALL_AMOUNT, 1);
        assertEq(IERC20(aaveYieldModule.baseToken()).balanceOf(address(aaveYieldModule)), 0);
        assertEq(IERC20(aaveYieldModule.baseToken()).balanceOf(address(smartFarmooor)), 0);
        assertEq(IERC20(aaveYieldModule.baseToken()).balanceOf(ALICE), SMALL_AMOUNT);
    }

    function testCanWithdrawAll() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        _withdraw(address(smartFarmooor), ALL_SHARE_AS_FRACTION, ALICE);
        
        assertEq(aaveYieldModule.getBalance(), 0);
        assertEq(IERC20(aaveYieldModule.baseToken()).balanceOf(address(aaveYieldModule)), 0);
        assertEq(IERC20(aaveYieldModule.baseToken()).balanceOf(address(smartFarmooor)), 0);
        assertEq(IERC20(aaveYieldModule.baseToken()).balanceOf(ALICE), SMALL_AMOUNT);
    }

    function testOnlySmartFarmooorCanWithdraw() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        _withdraw(address(smartFarmooor), ALL_SHARE_AS_FRACTION, ALICE);

        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert("BaseModule: only smart farmooor");
        aaveYieldModule.withdraw(ALL_SHARE_AS_FRACTION, ALICE);
    }

    function testOwnerCannotWithdraw() public {
        vm.prank(OWNER);
        vm.expectRevert("BaseModule: only smart farmooor");
        aaveYieldModule.withdraw(ALL_SHARE_AS_FRACTION, ALICE);
    }

    function testManagerCannotWithdraw() public {
        vm.prank(MANAGER);
        vm.expectRevert("BaseModule: only smart farmooor");
        aaveYieldModule.withdraw(ALL_SHARE_AS_FRACTION, ALICE);
    }

    function testWithdrawAmountCannotBeZero() public {
        vm.prank(address(smartFarmooor));
        vm.expectRevert("Aave: withdraw amount cannot be zero");
        aaveYieldModule.withdraw(0, ALICE);
    }

    function testMsgValueMustBeZeroToWithdraw() public {
        deal(address(smartFarmooor), 1e17);
        vm.prank(address(smartFarmooor));
        vm.expectRevert("Aave: msg.value must be zero");
        aaveYieldModule.withdraw{value : 1e17}(ALL_SHARE_AS_FRACTION, ALICE);
    }

    function testDepositEmitEvent() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);

        vm.startPrank(address(smartFarmooor));
        vm.expectEmit(false, false, false, true);
        emit Withdraw(aaveYieldModule.baseToken(), SMALL_AMOUNT);
        aaveYieldModule.withdraw(ALL_SHARE_AS_FRACTION, ALICE);
        vm.stopPrank();
    }

    function testShouldFailOnLpTokenRescueWithdrawal() public {
        // we can not deal aTokens cos it is not a regular ERC20 token - most functions are overridden and deal(..) does not work
        address lpToken = aaveYieldModule.aToken();
        vm.startPrank(OWNER);
        vm.expectRevert(bytes("BaseModule: can't pull out lp tokens"));
        aaveYieldModule.rescueToken(lpToken);
        vm.stopPrank();
    }

    function testShouldAllowTokenRescueWithdrawal() public {
        deal(aaveYieldModule.baseToken(), address(aaveYieldModule), SMALL_AMOUNT);
        _moveBlock(1);
        assertEq(IERC20(aaveYieldModule.baseToken()).balanceOf(OWNER), 0);
        vm.startPrank(OWNER);
        aaveYieldModule.rescueToken(aaveYieldModule.baseToken());
        assertEq(IERC20(aaveYieldModule.baseToken()).balanceOf(OWNER), SMALL_AMOUNT);
        vm.stopPrank();
    }
}