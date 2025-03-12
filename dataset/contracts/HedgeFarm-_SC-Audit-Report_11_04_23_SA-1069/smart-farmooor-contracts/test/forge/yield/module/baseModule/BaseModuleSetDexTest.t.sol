// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BaseModuleBaseTest.t.sol";

contract BaseModuleSetDexTest is BaseModuleBaseTest {

    function testSetDex() public {
        vm.prank(OWNER);
        baseModule.setDex(RANDOM_ADDRESS);
        assertEq(address(baseModule.dex()), RANDOM_ADDRESS);
        _verifyAllowance();
    }

    function testOnlyOwnerCanSetDex() public {
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        baseModule.setDex(RANDOM_ADDRESS);
    }

    function testCannotSetTheZeroAddressAsDex() public {
        vm.prank(OWNER);
        vm.expectRevert(bytes("BaseModule: cannot be the zero address"));
        baseModule.setDex(address(0));
    }

    function testCanSetDexWithTimelock() public {
        _transferOwnershipToTimelock();

        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        baseModule.setDex(address(0));

        vm.prank(OWNER);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        baseModule.setDex(address(0));

        vm.prank(address(timelock));
        baseModule.setDex(RANDOM_ADDRESS);

        vm.startPrank(OWNER);
        bytes32 id = timelock.hashOperation(address(baseModule), 0, abi.encodeWithSelector(BaseModule.setDex.selector, ALICE), bytes32(0), 0);
        assertEq(timelock.isOperation(id), false);
        timelock.schedule(address(baseModule), 0, abi.encodeWithSelector(BaseModule.setDex.selector, ALICE), bytes32(0), 0, TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperation(id), true);
        assertEq(timelock.isOperationPending(id), true);
        assertEq(timelock.isOperationReady(id), false);
        assertEq(timelock.isOperationDone(id), false);
        vm.warp(block.timestamp + TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperationReady(id), true);
        assertEq(timelock.isOperationDone(id), false);
        timelock.execute(address(baseModule), 0, abi.encodeWithSelector(BaseModule.setDex.selector, ALICE), bytes32(0), 0);
        assertEq(timelock.isOperationDone(id), true);
        vm.stopPrank();
        assertEq(address(baseModule.dex()), ALICE);
    }
}