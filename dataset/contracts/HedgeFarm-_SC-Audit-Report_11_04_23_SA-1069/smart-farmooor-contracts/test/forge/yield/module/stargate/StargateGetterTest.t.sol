// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./StargateBaseTest.t.sol";

contract StargateGetterTest is StargateBaseTest {

    function testCanGetBalance() public {
        assertEq(stargateYieldModule.getLastUpdatedBalance(), 0);
        assertEq(stargateYieldModule.getBalance(), 0);
        _deposit(address(smartFarmooor), SMALL_AMOUNT);
        assertApproxEqAbs(stargateYieldModule.getLastUpdatedBalance(), SMALL_AMOUNT, 1);
        assertApproxEqAbs(stargateYieldModule.getBalance(), SMALL_AMOUNT, 1);
        _moveBlock(1000);
        // NOTE: getBalance does not take into account the swap fee so it always returns the deposited amount
        assertApproxEqAbs(stargateYieldModule.getLastUpdatedBalance(), SMALL_AMOUNT, 1);
        assertApproxEqAbs(stargateYieldModule.getBalance(), SMALL_AMOUNT, 1);
        _harvest(address(smartFarmooor), SMALL_AMOUNT, address(smartFarmooor));
        assertApproxEqAbs(stargateYieldModule.getLastUpdatedBalance(), SMALL_AMOUNT, 1);
        assertApproxEqAbs(stargateYieldModule.getBalance(), SMALL_AMOUNT, 1);
        uint256 profit = IERC20(stargateYieldModule.baseToken()).balanceOf(address(smartFarmooor));
        _deposit(address(smartFarmooor), profit);
        assertApproxEqAbs(stargateYieldModule.getLastUpdatedBalance(), SMALL_AMOUNT + profit, 2);
        assertApproxEqAbs(stargateYieldModule.getBalance(), SMALL_AMOUNT + profit, 2);
        uint256 shareFractionTotal = _calculateTotalShareFraction();
        _withdraw(address(smartFarmooor), shareFractionTotal, ALICE);
        assertEq(stargateYieldModule.getLastUpdatedBalance(), 0);
        assertEq(stargateYieldModule.getBalance(), 0);
    }

    function testCanGetExecutionFee() public {
        _deposit(address(smartFarmooor), 3 * SMALL_AMOUNT);
        assertEq(stargateYieldModule.getExecutionFee(0), 0);
        StargateYieldModuleDeltaCreditMock(payable(stargateYieldModule)).setPoolDeltaCredit(SMALL_AMOUNT);
        uint256 shareFraction = _calculateShareFraction(SMALL_AMOUNT, 3 * SMALL_AMOUNT);
        assertEq(stargateYieldModule.getExecutionFee(shareFraction), 0);
        // here we are trying to get more than delta credits so async will kick in and we will use default execution fee
        shareFraction = _calculateShareFraction(2 * SMALL_AMOUNT, 3 * SMALL_AMOUNT);
        assertEq(stargateYieldModule.getExecutionFee(shareFraction), stargateYieldModule.executionFee());
    }
}