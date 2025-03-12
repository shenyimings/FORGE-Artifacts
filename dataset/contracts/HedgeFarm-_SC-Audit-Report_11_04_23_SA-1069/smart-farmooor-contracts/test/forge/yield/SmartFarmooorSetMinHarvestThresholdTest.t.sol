// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SmartFarmooorBasicTestHelperAvax.t.sol";

contract SmartFarmooorSetMinHarvestThresholdTest is SmartFarmooorBasicTestHelperAvax {

    function testCanSetMinHarvestThreshold() public {
        vm.prank(address(timelock));
        smartFarmooor.setMinHarvestThreshold(NEW_MIN_HARVEST_THRESHOLD);
        assertEq(smartFarmooor.minHarvestThreshold(), NEW_MIN_HARVEST_THRESHOLD);
    }

    function testOnlyOwnerCanSetMinHarvestThreshold() public {
        vm.prank(RANDOM_ADDRESS);
        //with RANDOM_ADDRESS == 0x305ad87a471f49520218feaf4146e26d9f068eb4
        vm.expectRevert(bytes('AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08'));
        smartFarmooor.setMinHarvestThreshold(NEW_MIN_HARVEST_THRESHOLD);
    }

    function testMinHarvestThresholdIsOnlyIfEmptyModuleThreshold() public {
        uint initialNumberOfModule = smartFarmooor.numberOfModules();

        depositHelper(ALICE, smartFarmooor.minAmount() * 10);

        vm.startPrank(address(timelock));
        smartFarmooor.pause();

        //do random admin action that requires onlyIfEmptyModule
        vm.expectRevert(bytes('SmartFarmooor: module not empty'));
        smartFarmooor.removeModule(0);

        smartFarmooor.setMinHarvestThreshold(smartFarmooor.minAmount() * 10);
        smartFarmooor.removeModule(0);

        assertEq(smartFarmooor.numberOfModules(), initialNumberOfModule - 1);
    }

    function testCanSetMinHarvestThresholdWithTimelock() public {
        vm.prank(RANDOM_ADDRESS);
        //with RANDOM_ADDRESS == 0x305ad87a471f49520218feaf4146e26d9f068eb4 and MANAGER_ROLE == 0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08
        vm.expectRevert(bytes('AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08'));
        smartFarmooor.setMinHarvestThreshold(NEW_MIN_HARVEST_THRESHOLD);

        vm.prank(OWNER);
        //with OWNER == 0x356f394005d3316ad54d8f22b40d02cd539a4a3c and MANAGER_ROLE == 0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08
        vm.expectRevert(bytes('AccessControl: account 0x356f394005d3316ad54d8f22b40d02cd539a4a3c is missing role 0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08'));
        smartFarmooor.setMinHarvestThreshold(NEW_MIN_HARVEST_THRESHOLD);

        vm.prank(address(timelock));
        smartFarmooor.setMinHarvestThreshold(NEW_MIN_HARVEST_THRESHOLD);

        vm.startPrank(OWNER);
        bytes32 id = timelock.hashOperation(address(smartFarmooor), 0, abi.encodeWithSelector(SmartFarmooor.setMinHarvestThreshold.selector, NEW_MIN_HARVEST_THRESHOLD + 1), bytes32(0), 0);
        assertEq(timelock.isOperation(id), false);
        timelock.schedule(address(smartFarmooor), 0, abi.encodeWithSelector(SmartFarmooor.setMinHarvestThreshold.selector, NEW_MIN_HARVEST_THRESHOLD + 1), bytes32(0), 0, TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperation(id), true);
        assertEq(timelock.isOperationPending(id), true);
        assertEq(timelock.isOperationReady(id), false);
        assertEq(timelock.isOperationDone(id), false);
        vm.warp(block.timestamp + TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperationReady(id), true);
        assertEq(timelock.isOperationDone(id), false);
        timelock.execute(address(smartFarmooor), 0, abi.encodeWithSelector(SmartFarmooor.setMinHarvestThreshold.selector, NEW_MIN_HARVEST_THRESHOLD + 1), bytes32(0), 0);
        assertEq(timelock.isOperationDone(id), true);
        vm.stopPrank();
        assertEq(smartFarmooor.minHarvestThreshold(), NEW_MIN_HARVEST_THRESHOLD + 1);
    }
}
