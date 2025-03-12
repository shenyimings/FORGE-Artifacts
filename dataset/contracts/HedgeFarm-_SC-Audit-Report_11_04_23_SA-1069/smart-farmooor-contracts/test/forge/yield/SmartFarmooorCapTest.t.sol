// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SmartFarmooorBasicTestHelperAvax.t.sol";

contract SmartFarmooorCapTest is SmartFarmooorBasicTestHelperAvax {

    function testSetCap() public {
        vm.prank(address(timelock));
        smartFarmooor.setCap(BIG_DEPOSIT_AMOUNT);
        assertEq(smartFarmooor.cap(), BIG_DEPOSIT_AMOUNT);
    }

    function testOnlyOwnerCanSetCap() public {
        vm.prank(RANDOM_ADDRESS);
        //with RANDOM_ADDRESS == 0x305ad87a471f49520218feaf4146e26d9f068eb4
        vm.expectRevert(bytes('AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000'));
        smartFarmooor.setCap(0);
    }

    function testCannotDepositMoreIfCapIsReached() public {
        vm.prank(address(timelock));
        smartFarmooor.setCap(DEPOSIT_AMOUNT * 2);

        depositHelper(ALICE, DEPOSIT_AMOUNT);

        vm.startPrank(ALICE);
        uint capPlus1 = DEPOSIT_AMOUNT + PRECISION;
        deal(BASE_TOKEN, ALICE, capPlus1);
        vm.expectRevert(bytes("SmartFarmooor: Cap reached"));
        smartFarmooor.deposit(capPlus1);

        assertEq(smartFarmooor.balanceOf(ALICE), DEPOSIT_AMOUNT);
    }

    function testCanSetCapWithTimelock() public {
        vm.prank(RANDOM_ADDRESS);
        //with RANDOM_ADDRESS == 0x305ad87a471f49520218feaf4146e26d9f068eb4
        vm.expectRevert(bytes('AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000'));
        smartFarmooor.setCap(BIG_DEPOSIT_AMOUNT);

        vm.prank(OWNER);
        //with address(timelock) == 0x356f394005d3316ad54d8f22b40d02cd539a4a3c
        vm.expectRevert(bytes('AccessControl: account 0x356f394005d3316ad54d8f22b40d02cd539a4a3c is missing role 0x0000000000000000000000000000000000000000000000000000000000000000'));
        smartFarmooor.setCap(BIG_DEPOSIT_AMOUNT);

        vm.prank(address(timelock));
        smartFarmooor.setCap(BIG_DEPOSIT_AMOUNT);

        vm.startPrank(OWNER);
        bytes32 id = timelock.hashOperation(address(smartFarmooor), 0, abi.encodeWithSelector(SmartFarmooor.setCap.selector, DEPOSIT_AMOUNT), bytes32(0), 0);
        assertEq(timelock.isOperation(id), false);
        timelock.schedule(address(smartFarmooor), 0, abi.encodeWithSelector(SmartFarmooor.setCap.selector, DEPOSIT_AMOUNT), bytes32(0), 0, TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperation(id), true);
        assertEq(timelock.isOperationPending(id), true);
        assertEq(timelock.isOperationReady(id), false);
        assertEq(timelock.isOperationDone(id), false);
        vm.warp(block.timestamp + TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperationReady(id), true);
        assertEq(timelock.isOperationDone(id), false);
        timelock.execute(address(smartFarmooor), 0, abi.encodeWithSelector(SmartFarmooor.setCap.selector, DEPOSIT_AMOUNT), bytes32(0), 0);
        assertEq(timelock.isOperationDone(id), true);
        vm.stopPrank();
        assertEq(smartFarmooor.cap(), DEPOSIT_AMOUNT);
    }
}
