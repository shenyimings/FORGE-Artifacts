// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SmartFarmooorBasicTestHelperAvax.t.sol";

contract SmartFarmooorSetMinAmountTest is SmartFarmooorBasicTestHelperAvax {

    function testSetMinAmount() public {
        vm.prank(address(timelock));
        smartFarmooor.setMinAmount(42);
        assertEq(smartFarmooor.minAmount(), 42);
    }

    function testOnlyOwnerCanSetMinAmount() public {
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes('AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000'));
        smartFarmooor.setMinAmount(42);
    }

    function testCanSetMinAmountWithTimelock() public {
        vm.prank(RANDOM_ADDRESS);
        //with RANDOM_ADDRESS == 0x305ad87a471f49520218feaf4146e26d9f068eb4
        vm.expectRevert(bytes('AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000'));
        smartFarmooor.setMinAmount(42);

        vm.prank(OWNER);
        //with OWNER == 0x356f394005d3316ad54d8f22b40d02cd539a4a3c
        vm.expectRevert(bytes('AccessControl: account 0x356f394005d3316ad54d8f22b40d02cd539a4a3c is missing role 0x0000000000000000000000000000000000000000000000000000000000000000'));
        smartFarmooor.setMinAmount(42);

        vm.prank(address(timelock));
        smartFarmooor.setMinAmount(42);

        vm.startPrank(OWNER);
        bytes32 id = timelock.hashOperation(address(smartFarmooor), 0, abi.encodeWithSelector(SmartFarmooor.setMinAmount.selector, 43), bytes32(0), 0);
        assertEq(timelock.isOperation(id), false);
        timelock.schedule(address(smartFarmooor), 0, abi.encodeWithSelector(SmartFarmooor.setMinAmount.selector, 43), bytes32(0), 0, TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperation(id), true);
        assertEq(timelock.isOperationPending(id), true);
        assertEq(timelock.isOperationReady(id), false);
        assertEq(timelock.isOperationDone(id), false);
        vm.warp(block.timestamp + TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperationReady(id), true);
        assertEq(timelock.isOperationDone(id), false);
        timelock.execute(address(smartFarmooor), 0, abi.encodeWithSelector(SmartFarmooor.setMinAmount.selector, 43), bytes32(0), 0);
        assertEq(timelock.isOperationDone(id), true);
        vm.stopPrank();
        assertEq(smartFarmooor.minAmount(), 43);
    }
}
