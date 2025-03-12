// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BaseModuleBaseTest.t.sol";

contract BaseModuleSetExecutionFeeTest is BaseModuleBaseTest {

    function testSetExecutionFee() public {
        vm.prank(OWNER);
        baseModule.setExecutionFee(0);
        assertEq(baseModule.executionFee(), 0);
    }

    function testOnlyOwnerCanSetExecutionFee() public {
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        baseModule.setExecutionFee(0);
    }

    function testCannotSetExecutionFeeHigherThanThreshold() public {
        vm.prank(OWNER);
        vm.expectRevert(bytes("BaseModule: execution fee must be less than 0.5 AVAX"));
        baseModule.setExecutionFee(6 * 1e17);
    }

    function testCanSetExecutionFeeWithTimelock() public {
        _transferOwnershipToTimelock();

        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        baseModule.setExecutionFee(0);

        vm.prank(OWNER);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        baseModule.setExecutionFee(0);

        vm.prank(address(timelock));
        baseModule.setExecutionFee(4 * 1e17);

        vm.startPrank(OWNER);
        bytes32 id = timelock.hashOperation(address(baseModule), 0, abi.encodeWithSelector(BaseModule.setExecutionFee.selector, 4 * 1e16), bytes32(0), 0);
        assertEq(timelock.isOperation(id), false);
        timelock.schedule(address(baseModule), 0, abi.encodeWithSelector(BaseModule.setExecutionFee.selector, 4 * 1e16), bytes32(0), 0, TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperation(id), true);
        assertEq(timelock.isOperationPending(id), true);
        assertEq(timelock.isOperationReady(id), false);
        assertEq(timelock.isOperationDone(id), false);
        vm.warp(block.timestamp + TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperationReady(id), true);
        assertEq(timelock.isOperationDone(id), false);
        timelock.execute(address(baseModule), 0, abi.encodeWithSelector(BaseModule.setExecutionFee.selector, 4 * 1e16), bytes32(0), 0);
        assertEq(timelock.isOperationDone(id), true);
        vm.stopPrank();
        assertEq(baseModule.executionFee(), 4 * 1e16);
    }
}