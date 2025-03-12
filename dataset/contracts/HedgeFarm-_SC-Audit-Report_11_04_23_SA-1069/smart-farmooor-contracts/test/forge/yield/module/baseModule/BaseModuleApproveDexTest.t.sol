// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BaseModuleBaseTest.t.sol";

contract BaseModuleApproveDexTest is BaseModuleBaseTest {

    function testApproveDexWhenTheTwoAllowanceIsZero() public {
        vm.startPrank(address(baseModule));
        IERC20(baseModule.rewards(0)).approve(baseModule.dex(), 0);
        IERC20(baseModule.rewards(1)).approve(baseModule.dex(), 0);
        vm.stopPrank();
        assertEq(IERC20(baseModule.rewards(0)).allowance(address(baseModule), baseModule.dex()), 0);
        assertEq(IERC20(baseModule.rewards(1)).allowance(address(baseModule), baseModule.dex()), 0);
        vm.prank(OWNER);
        baseModule.approveDex();
        _verifyAllowance();
    }

    function testApproveDexWhenOneAllowanceIsZeroAndOneAllowanceIsMax() public {
        vm.startPrank(address(baseModule));
        IERC20(baseModule.rewards(0)).approve(baseModule.dex(), 0);
        vm.stopPrank();
        assertEq(IERC20(baseModule.rewards(0)).allowance(address(baseModule), baseModule.dex()), 0);
        assertEq(IERC20(baseModule.rewards(1)).allowance(address(baseModule), baseModule.dex()), type(uint256).max);
        vm.prank(OWNER);
        baseModule.approveDex();
        _verifyAllowance();
    }

    function testApproveDexWhenTheTwoAllowanceIsMax() public {
        assertEq(IERC20(baseModule.rewards(0)).allowance(address(baseModule), baseModule.dex()), type(uint96).max);
        assertEq(IERC20(baseModule.rewards(1)).allowance(address(baseModule), baseModule.dex()), type(uint256).max);
        vm.prank(OWNER);
        baseModule.approveDex();
        _verifyAllowance();
    }

    function testApproveDexWhenTheTwoAllowanceIsBetweenZeroAndMax() public {
        vm.startPrank(address(baseModule));
        IERC20(baseModule.rewards(0)).approve(baseModule.dex(), type(uint96).max / 2);
        IERC20(baseModule.rewards(1)).approve(baseModule.dex(), type(uint256).max / 4);
        vm.stopPrank();
        assertEq(IERC20(baseModule.rewards(0)).allowance(address(baseModule), baseModule.dex()), type(uint96).max / 2);
        assertEq(IERC20(baseModule.rewards(1)).allowance(address(baseModule), baseModule.dex()), type(uint256).max / 4);
        vm.prank(OWNER);
        baseModule.approveDex();
        _verifyAllowance();
    }

    function testOnlyOwnerCanApproveDex() public {
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        baseModule.approveDex();
    }

    function testCanApproveDexWithTimelock() public {
        _transferOwnershipToTimelock();

        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        baseModule.approveDex();

        vm.prank(OWNER);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        baseModule.approveDex();

        vm.prank(address(timelock));
        baseModule.approveDex();

        vm.startPrank(OWNER);
        bytes32 id = timelock.hashOperation(address(baseModule), 0, abi.encodeWithSelector(BaseModule.approveDex.selector), bytes32(0), 0);
        assertEq(timelock.isOperation(id), false);
        timelock.schedule(address(baseModule), 0, abi.encodeWithSelector(BaseModule.approveDex.selector), bytes32(0), 0, TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperation(id), true);
        assertEq(timelock.isOperationPending(id), true);
        assertEq(timelock.isOperationReady(id), false);
        assertEq(timelock.isOperationDone(id), false);
        vm.warp(block.timestamp + TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperationReady(id), true);
        assertEq(timelock.isOperationDone(id), false);
        timelock.execute(address(baseModule), 0, abi.encodeWithSelector(BaseModule.approveDex.selector), bytes32(0), 0);
        assertEq(timelock.isOperationDone(id), true);
        vm.stopPrank();
        _verifyAllowance();
    }
}
