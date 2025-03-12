// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./StargateBaseTest.t.sol";

contract StargateWithdrawTest is StargateBaseTest {

    function testCanWithdrawSync() public {
        (uint256 instantAmount, uint256 pendingAmount) = _canWithdraw(SMALL_AMOUNT);
        assertApproxEqAbs(instantAmount, SMALL_AMOUNT, 2);
        assertEq(pendingAmount, 0);
    }

    function testCanWithdrawAsync() public {
        (uint256 instantAmount, uint256 pendingAmount) = _canWithdraw(SMALL_AMOUNT / 2);
        assertEq(instantAmount, 0);
        assertApproxEqAbs(pendingAmount, SMALL_AMOUNT, 2);
    }

    function testCanWithdrawAllSync() public {
        (uint256 instantAmount, uint256 pendingAmount) = _canWithdrawAll(BIG_AMOUNT);
        assertApproxEqAbs(instantAmount, BIG_AMOUNT, 1);
        assertEq(pendingAmount, 0);
    }

    function testCanWithdrawAllAsync() public {
        (uint256 instantAmount, uint256 pendingAmount) = _canWithdrawAll(SMALL_AMOUNT);
        assertEq(instantAmount, 0);
        assertApproxEqAbs(pendingAmount, BIG_AMOUNT, 1);
    }

    function testDepositAndWithdrawSeveralTime() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT / 5);
        _deposit(address(smartFarmooor), SMALL_AMOUNT / 5);
        _deposit(address(smartFarmooor), SMALL_AMOUNT / 5);
        _deposit(address(smartFarmooor), SMALL_AMOUNT / 5);
        _deposit(address(smartFarmooor), SMALL_AMOUNT / 5);
        StargateYieldModuleDeltaCreditMock(payable(stargateYieldModule)).setPoolDeltaCredit(SMALL_AMOUNT);

        uint256 shareFraction = _calculateShareFraction(SMALL_AMOUNT, SMALL_AMOUNT * 2); // 50%

        (uint256 instantAmount0, ) = _withdraw(address(smartFarmooor), shareFraction, ALICE);  // 0.5 total
        (uint256 instantAmount1, ) = _withdraw(address(smartFarmooor), shareFraction, ALICE);  // 0.25 total  (50% of what was left)
        (uint256 instantAmount2, ) = _withdraw(address(smartFarmooor), shareFraction, ALICE);  // 0.125 total (50% of what was left)
        (uint256 instantAmount3, ) = _withdraw(address(smartFarmooor), _calculateTotalShareFraction(), ALICE);  // all the rest
        uint256 instantAmount = instantAmount0 + instantAmount1 + instantAmount2 + instantAmount3;

        assertEq(stargateYieldModule.getBalance(), 0);
        assertEq(IERC20(stargateYieldModule.baseToken()).balanceOf(address(stargateYieldModule)), 0);
        assertEq(IERC20(stargateYieldModule.baseToken()).balanceOf(address(smartFarmooor)), 0);
        assertEq(IERC20(stargateYieldModule.baseToken()).balanceOf(ALICE), instantAmount);
        // NOTE: we lose at most 1 wei per withdraw and deposit ?
        assertApproxEqAbs(instantAmount, SMALL_AMOUNT, 9);
    }

    function testOnlySmartFarmooorCanWithdraw() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        _withdraw(address(smartFarmooor), _calculateTotalShareFraction(), ALICE);

        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert("BaseModule: only smart farmooor");
        stargateYieldModule.withdraw(_calculateTotalShareFraction(), ALICE);
    }

    function testOwnerCannotWithdraw() public {
        vm.prank(OWNER);
        vm.expectRevert("BaseModule: only smart farmooor");
        stargateYieldModule.withdraw(_calculateTotalShareFraction(), ALICE);
    }

    function testManagerCannotWithdraw() public {
        vm.prank(MANAGER);
        vm.expectRevert("BaseModule: only smart farmooor");
        stargateYieldModule.withdraw(_calculateTotalShareFraction(), ALICE);
    }

    function testWithdrawAmountCannotBeZero() public {
        vm.prank(address(smartFarmooor));
        vm.expectRevert("Stargate: withdraw shareFraction cannot be zero");
        stargateYieldModule.withdraw(0, ALICE);
    }

    function testCannotWithdrawAsyncIfMsgValueIsLessThanExecutionFee() public {
        _deposit(address(smartFarmooor), BIG_AMOUNT);
        StargateYieldModuleDeltaCreditMock(payable(stargateYieldModule)).setPoolDeltaCredit(SMALL_AMOUNT);
        uint256 executionFee = stargateYieldModule.getExecutionFee(_calculateTotalShareFraction()) / 2;
        assertGt(executionFee, 0);
        deal(address(smartFarmooor), executionFee);
        vm.prank(address(smartFarmooor));
        vm.expectRevert("Stargate: cannot withdraw because msg.value < executionFee");
        stargateYieldModule.withdraw{value : executionFee}(_calculateTotalShareFraction(), ALICE);
    }

    function testDepositEmitEvent() public {
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        StargateYieldModuleDeltaCreditMock(payable(stargateYieldModule)).setPoolDeltaCredit(SMALL_AMOUNT);

        vm.startPrank(address(smartFarmooor));
        vm.expectEmit(false, false, false, false);
        emit Withdraw(stargateYieldModule.baseToken(), SMALL_AMOUNT);
        stargateYieldModule.withdraw(_calculateTotalShareFraction(), ALICE);
        vm.stopPrank();
    }

    /** helper **/

    function _canWithdraw(uint256 _deltaCredit) internal returns (uint256 instantAmount, uint256 pendingAmount) {
        uint256 deltaCredit = _deltaCredit;
        uint256 shareFraction = _calculateShareFraction(SMALL_AMOUNT, BIG_AMOUNT); 
        _deposit(address(smartFarmooor), BIG_AMOUNT);
        StargateYieldModuleDeltaCreditMock(payable(stargateYieldModule)).setPoolDeltaCredit(deltaCredit);
        (uint256 instantAmount, uint256 pendingAmount) = _withdraw(address(smartFarmooor), shareFraction, ALICE);
        
        assertApproxEqAbs(stargateYieldModule.getBalance(), BIG_AMOUNT - SMALL_AMOUNT, 1);
        assertEq(IERC20(stargateYieldModule.baseToken()).balanceOf(address(stargateYieldModule)), 0);
        assertEq(IERC20(stargateYieldModule.baseToken()).balanceOf(address(smartFarmooor)), 0);
        assertEq(IERC20(stargateYieldModule.baseToken()).balanceOf(ALICE), instantAmount);

        _moveBlock(10);
        // simulate stargate async withdraw
        deal(stargateYieldModule.baseToken(), ALICE, instantAmount + pendingAmount);
        assertEq(IERC20(stargateYieldModule.baseToken()).balanceOf(ALICE), instantAmount + pendingAmount);

        return (instantAmount, pendingAmount);
    }
    
    function _canWithdrawAll(uint256 _deltaCredit) internal returns (uint256 instantAmount, uint256 pendingAmount) {
        uint256 deltaCredit = _deltaCredit;
        uint256 shareFractionAmount = _calculateShareFraction(BIG_AMOUNT, BIG_AMOUNT);  
        _deposit(address(smartFarmooor), BIG_AMOUNT);
        StargateYieldModuleDeltaCreditMock(payable(stargateYieldModule)).setPoolDeltaCredit(deltaCredit);
        (uint256 instantAmount, uint256 pendingAmount) = _withdraw(address(smartFarmooor), shareFractionAmount, ALICE);
        
        assertEq(stargateYieldModule.getBalance(), 0);
        assertEq(IERC20(stargateYieldModule.baseToken()).balanceOf(address(stargateYieldModule)), 0);
        assertEq(IERC20(stargateYieldModule.baseToken()).balanceOf(address(smartFarmooor)), 0);
        assertEq(IERC20(stargateYieldModule.baseToken()).balanceOf(ALICE), instantAmount);

        _moveBlock(10);
        // simulate stargate async withdraw
        deal(stargateYieldModule.baseToken(), ALICE, instantAmount + pendingAmount);
        assertEq(IERC20(stargateYieldModule.baseToken()).balanceOf(ALICE), instantAmount + pendingAmount);

        return (instantAmount, pendingAmount);
    }

    function testShouldFailOnLpTokenRescueWithdrawal() public {
        address lpToken = STARGATE_POOL;
        deal(lpToken, address(stargateYieldModule), SMALL_AMOUNT);
        _moveBlock(1);
        vm.startPrank(OWNER);
        vm.expectRevert(bytes("BaseModule: can't pull out lp tokens"));
        stargateYieldModule.rescueToken(lpToken);
        vm.stopPrank();
    }

    function testShouldAllowTokenRescueWithdrawal() public {
        deal(stargateYieldModule.baseToken(), address(stargateYieldModule), SMALL_AMOUNT);
        _moveBlock(1);
        assertEq(IERC20(stargateYieldModule.baseToken()).balanceOf(OWNER), 0);
        vm.startPrank(OWNER);
        stargateYieldModule.rescueToken(stargateYieldModule.baseToken());
        assertEq(IERC20(stargateYieldModule.baseToken()).balanceOf(OWNER), SMALL_AMOUNT);
        vm.stopPrank();
    }
}
