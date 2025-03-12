// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./StargateBaseTest.t.sol";

contract StargateSetLpProfitWithdrawalThresholdTest is StargateBaseTest {
    uint256 newThreshold = 42 * 10**IERC20Metadata(USDC).decimals();

    function testCanSetLpProfitWithdrawalThreshold() public {
        vm.prank(OWNER);
        stargateYieldModule.setLpProfitWithdrawalThreshold(newThreshold);
        assertEq(stargateYieldModule.lpProfitWithdrawalThreshold(), newThreshold);
    }

    function testOnlyOwnerCanSetLpProfitWithdrawalThreshold() public {
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("BaseModule: only manager or owner"));
        stargateYieldModule.setLpProfitWithdrawalThreshold(newThreshold);
    }

    function testCannotSetLpProfitWithdrawalThresholdSmallerThanOne() public {
        newThreshold = 10**(IERC20Metadata(USDC).decimals()-1);
        vm.prank(OWNER);
        vm.expectRevert(bytes("Stargate: lpProfitWithdrawalThreshold must be at least 1 dollar"));
        stargateYieldModule.setLpProfitWithdrawalThreshold(newThreshold);
    }

    function testCanSetLpProfitWithdrawalThresholdWithTimelock() public {
        _transferOwnershipToTimelock();

        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("BaseModule: only manager or owner"));
        stargateYieldModule.setLpProfitWithdrawalThreshold(newThreshold);

        vm.prank(OWNER);
        vm.expectRevert(bytes("BaseModule: only manager or owner"));
        stargateYieldModule.setLpProfitWithdrawalThreshold(newThreshold);

        vm.prank(address(timelock));
        stargateYieldModule.setLpProfitWithdrawalThreshold(newThreshold);

        vm.startPrank(OWNER);
        bytes32 id = timelock.hashOperation(address(stargateYieldModule), 0, abi.encodeWithSelector(StargateYieldModule.setLpProfitWithdrawalThreshold.selector, newThreshold+1), bytes32(0), 0);
        assertEq(timelock.isOperation(id), false);
        timelock.schedule(address(stargateYieldModule), 0, abi.encodeWithSelector(StargateYieldModule.setLpProfitWithdrawalThreshold.selector, newThreshold+1), bytes32(0), 0, TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperation(id), true);
        assertEq(timelock.isOperationPending(id), true);
        assertEq(timelock.isOperationReady(id), false);
        assertEq(timelock.isOperationDone(id), false);
        vm.warp(block.timestamp + TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperationReady(id), true);
        assertEq(timelock.isOperationDone(id), false);
        timelock.execute(address(stargateYieldModule), 0, abi.encodeWithSelector(StargateYieldModule.setLpProfitWithdrawalThreshold.selector, newThreshold+1), bytes32(0), 0);
        assertEq(timelock.isOperationDone(id), true);
        vm.stopPrank();
        assertEq(stargateYieldModule.lpProfitWithdrawalThreshold(), newThreshold+1);
    }
}