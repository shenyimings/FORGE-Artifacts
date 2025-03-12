 // SPDX-License-Identifier: MIT
 pragma solidity ^0.8.0;

 import "./SmartFarmooorBasicTestHelperAvax.t.sol";

 contract SmartFarmooorStressTest is SmartFarmooorBasicTestHelperAvax {

     function testStressTestDepositInSameBlock() public {
        vm.prank(address(timelock));
        smartFarmooor.setCap(DEPOSIT_AMOUNT * 1000);
        for (uint256 i = 420; i < 520; i++) {
            address addr = address(uint160(i));
            depositHelper(addr, DEPOSIT_AMOUNT);
            assertEq(IERC20(BASE_TOKEN).balanceOf(addr), 0);
            assertApproxEqAbs(smartFarmooor.balanceOf(addr), DEPOSIT_AMOUNT, PRECISION);
        }
     }

     function testStressTestDepositInDifferentBlock() public {
        vm.prank(address(timelock));
        smartFarmooor.setCap(DEPOSIT_AMOUNT * 1000);
        for (uint256 i = 420; i < 520; i++) {
            _moveBlock(1);
            address addr = address(uint160(i));
            depositHelper(addr, DEPOSIT_AMOUNT);
            assertEq(IERC20(BASE_TOKEN).balanceOf(addr), 0);
            assertApproxEqAbs(smartFarmooor.balanceOf(addr), DEPOSIT_AMOUNT, PRECISION * i);
        }
     }

     function testStressTestWithdrawInSameBlock() public {
        testStressTestDepositInSameBlock();
        _moveBlock(1);

        for (uint256 i = 420; i < 520; i++) {
            address addr = address(uint160(i));
            uint256 shares = smartFarmooor.balanceOf(addr);
            withdrawHelper(addr, shares);
            assertApproxEqAbs(IERC20(BASE_TOKEN).balanceOf(addr), DEPOSIT_AMOUNT, PRECISION * 2);
            assertEq(smartFarmooor.balanceOf(addr), 0);
        }
     }

     function testStressTestWithdrawInDifferentBlock() public {
        testStressTestDepositInDifferentBlock();
        _moveBlock(1);

        for (uint256 i = 420; i < 520; i++) {
            _moveBlock(1);
            address addr = address(uint160(i));
            uint256 shares = smartFarmooor.balanceOf(addr);
            withdrawHelper(addr, shares);
            assertGt(IERC20(BASE_TOKEN).balanceOf(addr), DEPOSIT_AMOUNT - PRECISION);
            assertEq(smartFarmooor.balanceOf(addr), 0);
        }
     }

     function testStressDepositWithdrawInSameBlock() public {
        for (uint256 i = 420; i < 520; i++) {
            address addr = address(uint160(i));
            depositHelper(addr, DEPOSIT_AMOUNT);
            assertEq(IERC20(BASE_TOKEN).balanceOf(addr), 0);
            assertEq(smartFarmooor.balanceOf(addr), DEPOSIT_AMOUNT);
            uint256 shares = smartFarmooor.balanceOf(addr);
            withdrawHelper(addr, shares);
            assertApproxEqAbs(IERC20(BASE_TOKEN).balanceOf(addr), DEPOSIT_AMOUNT, PRECISION);
            assertEq(smartFarmooor.balanceOf(addr), 0);
        }
     }

     function testStressDepositWithdrawInDifferentBlock() public {
        for (uint256 i = 420; i < 520; i++) {
            address addr = address(uint160(i));
            depositHelper(addr, DEPOSIT_AMOUNT);
            assertEq(IERC20(BASE_TOKEN).balanceOf(addr), 0);
            assertEq(smartFarmooor.balanceOf(addr), DEPOSIT_AMOUNT);
            _moveBlock(1);
            withdrawHelper(addr, DEPOSIT_AMOUNT);
            assertApproxEqAbs(IERC20(BASE_TOKEN).balanceOf(addr), DEPOSIT_AMOUNT, PRECISION);
            assertEq(smartFarmooor.balanceOf(addr), 0);
        }
     }

     function testStressDepositHarvestWithdraw() public {
        for (uint256 i = 420; i < 520; i++) {
            address addr = address(uint160(i));
            depositHelper(addr, DEPOSIT_AMOUNT);
            assertEq(IERC20(BASE_TOKEN).balanceOf(addr), 0);
            assertEq(smartFarmooor.balanceOf(addr), DEPOSIT_AMOUNT);
            _moveBlock(1000);
            smartFarmooor.harvest();
            _moveBlock(10);
            withdrawHelper(addr, DEPOSIT_AMOUNT);
            assertGt(IERC20(BASE_TOKEN).balanceOf(addr), DEPOSIT_AMOUNT);
            assertEq(smartFarmooor.balanceOf(addr), 0);
        }
     }
}