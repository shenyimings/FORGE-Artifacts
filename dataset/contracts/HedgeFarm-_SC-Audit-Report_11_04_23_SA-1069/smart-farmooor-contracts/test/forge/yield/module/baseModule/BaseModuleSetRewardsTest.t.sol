// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BaseModuleBaseTest.t.sol";

contract BaseModuleSetRewardsTest is BaseModuleBaseTest {

    function testSetRewards() public {
        vm.prank(OWNER);
        baseModule.setRewards(rewards);
        assertEq(baseModule.rewards(0), rewards[0]);
        assertEq(baseModule.rewards(1), rewards[1]);
        _verifyAllowance();
    }

    function testOnlyOwnerCanSetRewards() public {
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        baseModule.setRewards(rewards);
    }

    function testCannotSetTheZeroAddressAsRewards() public {
        rewards[0] = address(0);
        vm.prank(OWNER);
        vm.expectRevert(bytes("BaseModule: cannot be the zero address"));
        baseModule.setRewards(rewards);
    }

    function testCanSetRewardsWithTimelock() public {
        _transferOwnershipToTimelock();

        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        baseModule.setRewards(rewards);

        vm.prank(OWNER);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        baseModule.setRewards(rewards);

        vm.prank(address(timelock));
        baseModule.setRewards(rewards);

        rewards[rewards.length -1] = USDC;

        vm.startPrank(OWNER);
        bytes32 id = timelock.hashOperation(address(baseModule), 0, abi.encodeWithSelector(BaseModule.setRewards.selector, rewards), bytes32(0), 0);
        assertEq(timelock.isOperation(id), false);
        timelock.schedule(address(baseModule), 0, abi.encodeWithSelector(BaseModule.setRewards.selector, rewards), bytes32(0), 0, TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperation(id), true);
        assertEq(timelock.isOperationPending(id), true);
        assertEq(timelock.isOperationReady(id), false);
        assertEq(timelock.isOperationDone(id), false);
        vm.warp(block.timestamp + TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperationReady(id), true);
        assertEq(timelock.isOperationDone(id), false);
        timelock.execute(address(baseModule), 0, abi.encodeWithSelector(BaseModule.setRewards.selector, rewards), bytes32(0), 0);
        assertEq(timelock.isOperationDone(id), true);
        vm.stopPrank();
        assertEq(baseModule.rewards(0), rewards[0]);
        assertEq(baseModule.rewards(1), rewards[1]);
    }
}