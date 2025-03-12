// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CompoundV2BaseTest.t.sol";

contract CompoundV2GetterTest is CompoundV2BaseTest {

    function testCanGetBalance() public {
        assertEq(yieldModule.getLastUpdatedBalance(), 0);
        assertEq(yieldModule.getBalance(), 0);
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        assertApproxEqAbs(yieldModule.getLastUpdatedBalance(), SMALL_AMOUNT, PRECISION);
        assertApproxEqAbs(yieldModule.getBalance(), SMALL_AMOUNT, PRECISION);
        _moveBlock(1000);
        assertApproxEqAbs(yieldModule.getLastUpdatedBalance(), SMALL_AMOUNT, PRECISION);
        assertGt(yieldModule.getBalance(), SMALL_AMOUNT);
        _harvest(address(smartFarmooor), address(smartFarmooor));
        assertApproxEqAbs(yieldModule.getLastUpdatedBalance(), SMALL_AMOUNT, PRECISION);
        assertApproxEqAbs(yieldModule.getBalance(), SMALL_AMOUNT, PRECISION);
        uint256 profit = IERC20(yieldModule.baseToken()).balanceOf(address(smartFarmooor));
        _deposit(address(smartFarmooor), profit);
        assertApproxEqAbs(yieldModule.getLastUpdatedBalance(), SMALL_AMOUNT + profit, PRECISION);
        assertApproxEqAbs(yieldModule.getBalance(), SMALL_AMOUNT + profit, PRECISION);
        _withdraw(address(smartFarmooor), ALL_SHARE_AS_FRACTION, ALICE);
        assertEq(yieldModule.getLastUpdatedBalance(), 0);
        assertEq(yieldModule.getBalance(), 0);
    }

    function testCanGetExectionFee() public {
        assertEq(yieldModule.getExecutionFee(0), 0);
        assertEq(yieldModule.getExecutionFee(SMALL_AMOUNT), 0);
        assertEq(yieldModule.getExecutionFee(BIG_AMOUNT), 0);
    }
}