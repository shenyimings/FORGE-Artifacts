 // SPDX-License-Identifier: MIT
 pragma solidity ^0.8.0;

 import "./SmartFarmooorBasicTestHelperAvax.t.sol";

 contract SmartFarmooorSetPerformanceFeeTest is SmartFarmooorBasicTestHelperAvax {

     function testSetPerformanceFee() public {
         vm.prank(address(timelock));
         smartFarmooor.setPerformanceFee(0);
         assertEq(smartFarmooor.performanceFee(), 0);
     }

     function testOnlyOwnerCanSetPerformanceFee() public {
         vm.prank(RANDOM_ADDRESS);
         vm.expectRevert(bytes('AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000'));
         smartFarmooor.setPerformanceFee(0);
     }

     function testCannotSetPerformanceFeeHigherThanThreshold() public {
         vm.prank(address(timelock));
         vm.expectRevert(bytes("SmartFarmooor: performanceFee fee must be less than 20%"));
         smartFarmooor.setPerformanceFee(2001);
     }

     function testCanSetPerformanceFeeWithTimelock() public {
        vm.prank(RANDOM_ADDRESS);
         //with RANDOM_ADDRESS == 0x305ad87a471f49520218feaf4146e26d9f068eb4
        vm.expectRevert(bytes('AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000'));
        smartFarmooor.setPerformanceFee(0);

        vm.prank(OWNER);
         //with OWNER == 0x356f394005d3316ad54d8f22b40d02cd539a4a3c
        vm.expectRevert(bytes('AccessControl: account 0x356f394005d3316ad54d8f22b40d02cd539a4a3c is missing role 0x0000000000000000000000000000000000000000000000000000000000000000'));
        smartFarmooor.setPerformanceFee(0);

        vm.prank(address(timelock));
        smartFarmooor.setPerformanceFee(0);

        vm.startPrank(OWNER);
        bytes32 id = timelock.hashOperation(address(smartFarmooor), 0, abi.encodeWithSelector(SmartFarmooor.setPerformanceFee.selector, 42), bytes32(0), 0);
        assertEq(timelock.isOperation(id), false);
        timelock.schedule(address(smartFarmooor), 0, abi.encodeWithSelector(SmartFarmooor.setPerformanceFee.selector, 42), bytes32(0), 0, TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperation(id), true);
        assertEq(timelock.isOperationPending(id), true);
        assertEq(timelock.isOperationReady(id), false);
        assertEq(timelock.isOperationDone(id), false);
        vm.warp(block.timestamp + TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperationReady(id), true);
        assertEq(timelock.isOperationDone(id), false);
        timelock.execute(address(smartFarmooor), 0, abi.encodeWithSelector(SmartFarmooor.setPerformanceFee.selector, 42), bytes32(0), 0);
        assertEq(timelock.isOperationDone(id), true);
        vm.stopPrank();
        assertEq(smartFarmooor.performanceFee(), 42);
    }
 }
