// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SmartFarmooorBasicTestHelperAvax.t.sol";

contract SmartFarmooorGettersTestAvax is SmartFarmooorBasicTestHelperAvax {
    using SafeERC20 for IERC20;

    function testModuleBalanceImpreciseAtDeposit() public {
        assertEq(smartFarmooor.getLastUpdatedModulesBalance(), 0);
        assertEq(smartFarmooor.getModulesBalance(), 0);
        depositHelper(ALICE, DEPOSIT_AMOUNT);
        assertApproxEqAbs(smartFarmooor.getLastUpdatedModulesBalance(), DEPOSIT_AMOUNT, PRECISION);
        assertApproxEqAbs(smartFarmooor.getModulesBalance(), DEPOSIT_AMOUNT, PRECISION);
        _moveBlock(1000);
        assertLe(smartFarmooor.getLastUpdatedModulesBalance(), smartFarmooor.getModulesBalance());

        //No LP Profits for sAVAX token across all modules
        if(BASE_TOKEN == SAVAX) {
            assertEq(smartFarmooor.getModulesBalance(), smartFarmooor.getLastUpdatedModulesBalance());
        } else  {
            assertGt(smartFarmooor.getModulesBalance(), DEPOSIT_AMOUNT);
            assertGt(smartFarmooor.getLastUpdatedModulesBalance(), DEPOSIT_AMOUNT);
        }
    }

    function testGetExecutionFee() public {
        depositHelper(ALICE, DEPOSIT_AMOUNT);

        uint256 executionFeeSmallAmount = smartFarmooor.getExecutionFee(1e18);
        uint256 expectedExecutionFeeSmallAmount = 0;
        for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
            (IYieldModule module, ) = smartFarmooor.yieldOptions(i);
            expectedExecutionFeeSmallAmount += module.getExecutionFee(1e18);
        }
        assertEq(executionFeeSmallAmount, expectedExecutionFeeSmallAmount);
        assertEq(executionFeeSmallAmount, 0);

        if (address(stargateYieldModule) != address(0)) {
            vm.mockCall(
                address(stargateYieldModule),
                abi.encodeWithSelector(StargateYieldModule.getExecutionFee.selector),
                abi.encode(300000000000000000) // 0.03 AVAX
            );

            uint256 executionFeeBigAmount = smartFarmooor.getExecutionFee(1e18);
            uint256 expectedExecutionFeeBigAmount = 0;
            for (uint256 i = 0; i < smartFarmooor.numberOfModules(); i++) {
                (IYieldModule module, ) = smartFarmooor.yieldOptions(i);
                expectedExecutionFeeBigAmount += module.getExecutionFee(1e18);
            }
            assertEq(executionFeeBigAmount, expectedExecutionFeeBigAmount);
            assertGt(executionFeeBigAmount, 0);
        }
    }
}
