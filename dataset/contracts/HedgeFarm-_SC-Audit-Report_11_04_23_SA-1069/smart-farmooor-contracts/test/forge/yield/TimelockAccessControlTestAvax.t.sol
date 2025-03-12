// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../script/Deployer.s.sol";
import "../helper/TestHelper.sol";

contract TimelockAccessControlTestAvax is Deployer, TestHelper {

    address[][] public dummyRoutes = [[QI, USDC, BTCB, SAVAX]];

    function setUp() public {
        loadTestData();
        deployTimelock();
        deployDex();
        transferOwnershipDex(address(timelock));
    }

    function testInitIsCorrect() public {
        verifyTimelock();
    }
    
    function testOnlyProposerCanSchedule() public {
        vm.startPrank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1"));
        timelock.schedule(address(dex), 0, abi.encodeWithSelector(TraderJoeDexModule.setRoutes.selector, routes), bytes32(0), 0, TIMELOCK_MIN_DELAY);
        vm.stopPrank();

        vm.startPrank(DEPLOYER);
        vm.expectRevert(bytes("AccessControl: account 0x3a383b39c10856a75b9e3f6eda6fcc8fc3334050 is missing role 0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1"));
        timelock.schedule(address(dex), 0, abi.encodeWithSelector(TraderJoeDexModule.setRoutes.selector, routes), bytes32(0), 0, TIMELOCK_MIN_DELAY);
        vm.stopPrank();

        vm.startPrank(OWNER);
        bytes32 id = timelock.hashOperation(address(dex), 0, abi.encodeWithSelector(TraderJoeDexModule.setRoutes.selector, routes), bytes32(0), 0);
        timelock.schedule(address(dex), 0, abi.encodeWithSelector(TraderJoeDexModule.setRoutes.selector, routes), bytes32(0), 0, TIMELOCK_MIN_DELAY);
        vm.stopPrank();
        assertEq(timelock.isOperation(id), true);
    }

    function testOnlyExecutorCanExecute() public {
        testOnlyProposerCanSchedule();
        vm.warp(block.timestamp + TIMELOCK_MIN_DELAY);

        vm.startPrank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0xd8aa0f3194971a2a116679f7c2090f6939c8d4e01a2a8d7e41d55e5351469e63"));
        timelock.execute(address(dex), 0, abi.encodeWithSelector(TraderJoeDexModule.setRoutes.selector, routes), bytes32(0), 0);
        vm.stopPrank();

        vm.startPrank(DEPLOYER);
        vm.expectRevert(bytes("AccessControl: account 0x3a383b39c10856a75b9e3f6eda6fcc8fc3334050 is missing role 0xd8aa0f3194971a2a116679f7c2090f6939c8d4e01a2a8d7e41d55e5351469e63"));
        timelock.execute(address(dex), 0, abi.encodeWithSelector(TraderJoeDexModule.setRoutes.selector, routes), bytes32(0), 0);
        vm.stopPrank();

        vm.startPrank(OWNER);
        bytes32 id = timelock.hashOperation(address(dex), 0, abi.encodeWithSelector(TraderJoeDexModule.setRoutes.selector, routes), bytes32(0), 0);
        timelock.execute(address(dex), 0, abi.encodeWithSelector(TraderJoeDexModule.setRoutes.selector, routes), bytes32(0), 0);
        vm.stopPrank();
        assertEq(timelock.isOperationDone(id), true);
    }

    function testOnlyCancellerCanCancel() public {
        testOnlyProposerCanSchedule();
        vm.warp(block.timestamp + TIMELOCK_MIN_DELAY);
        bytes32 id = timelock.hashOperation(address(dex), 0, abi.encodeWithSelector(TraderJoeDexModule.setRoutes.selector, routes), bytes32(0), 0);

        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0xfd643c72710c63c0180259aba6b2d05451e3591a24e58b62239378085726f783"));
        timelock.cancel(id);

        vm.prank(DEPLOYER);
        vm.expectRevert(bytes("AccessControl: account 0x3a383b39c10856a75b9e3f6eda6fcc8fc3334050 is missing role 0xfd643c72710c63c0180259aba6b2d05451e3591a24e58b62239378085726f783"));
        timelock.cancel(id);

        vm.prank(OWNER);
        timelock.cancel(id);
        assertEq(timelock.isOperation(id), false);
    }

    function testNobodyCanUpdateMinDelayExpectTimelock() public {
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("TimelockController: caller must be timelock"));
        timelock.updateDelay(42);

        vm.prank(DEPLOYER);
        vm.expectRevert(bytes("TimelockController: caller must be timelock"));
        timelock.updateDelay(42);

        vm.prank(OWNER);
        vm.expectRevert(bytes("TimelockController: caller must be timelock"));
        timelock.updateDelay(42);

        vm.prank(address(timelock));
        timelock.updateDelay(42);
        assertEq(timelock.getMinDelay(), 42);
    }

    function testNobodyCanGrantRoleExpectTimelock() public {
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0x5f58e3a2316349923ce3780f8d587db2d72378aed66a8261c916544fa6846ca5"));
        timelock.grantRole(keccak256("EXECUTOR_ROLE"), RANDOM_ADDRESS);

        vm.prank(TIMELOCK_ADMIN);
        vm.expectRevert(bytes("AccessControl: account 0x0000000000000000000000000000000000000000 is missing role 0x5f58e3a2316349923ce3780f8d587db2d72378aed66a8261c916544fa6846ca5"));
        timelock.grantRole(keccak256("EXECUTOR_ROLE"), RANDOM_ADDRESS);

        assertTrue(!timelock.hasRole(keccak256("EXECUTOR_ROLE"), RANDOM_ADDRESS));
        vm.prank(address(timelock));
        timelock.grantRole(keccak256("EXECUTOR_ROLE"), RANDOM_ADDRESS);
        assertTrue(timelock.hasRole(keccak256("EXECUTOR_ROLE"), RANDOM_ADDRESS));
    }

    function testNobodyCanRevokeRoleExpectTimelock() public {
        testNobodyCanGrantRoleExpectTimelock();

        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0x5f58e3a2316349923ce3780f8d587db2d72378aed66a8261c916544fa6846ca5"));
        timelock.revokeRole(keccak256("EXECUTOR_ROLE"), RANDOM_ADDRESS);

        vm.prank(TIMELOCK_ADMIN);
        vm.expectRevert(bytes("AccessControl: account 0x0000000000000000000000000000000000000000 is missing role 0x5f58e3a2316349923ce3780f8d587db2d72378aed66a8261c916544fa6846ca5"));
        timelock.revokeRole(keccak256("EXECUTOR_ROLE"), RANDOM_ADDRESS);

        vm.prank(address(timelock));
        timelock.revokeRole(keccak256("EXECUTOR_ROLE"), RANDOM_ADDRESS);
        assertTrue(!timelock.hasRole(keccak256("EXECUTOR_ROLE"), RANDOM_ADDRESS));
    }

    function testCanGrantATimelockRoleThroughTheTimelock () public {
        vm.startPrank(OWNER);
        bytes32 id = timelock.hashOperation(address(dex), 0, abi.encodeWithSelector(AccessControl.grantRole.selector, keccak256("EXECUTOR_ROLE"), RANDOM_ADDRESS), bytes32(0), 0);
        timelock.schedule(address(timelock), 0, abi.encodeWithSelector(AccessControl.grantRole.selector, keccak256("EXECUTOR_ROLE"), RANDOM_ADDRESS), bytes32(0), 0, TIMELOCK_MIN_DELAY);
        vm.warp(block.timestamp + TIMELOCK_MIN_DELAY);
        timelock.execute(address(timelock), 0, abi.encodeWithSelector(AccessControl.grantRole.selector, keccak256("EXECUTOR_ROLE"), RANDOM_ADDRESS), bytes32(0), 0);
        vm.stopPrank();
        assertTrue(timelock.hasRole(keccak256("EXECUTOR_ROLE"), RANDOM_ADDRESS));
    }

    function testCanRevokeATimelockRoleThroughTheTimelock () public {
        testCanGrantATimelockRoleThroughTheTimelock();

        vm.startPrank(OWNER);
        bytes32 id = timelock.hashOperation(address(dex), 0, abi.encodeWithSelector(AccessControl.revokeRole.selector, keccak256("EXECUTOR_ROLE"), RANDOM_ADDRESS), bytes32(0), 0);
        timelock.schedule(address(timelock), 0, abi.encodeWithSelector(AccessControl.revokeRole.selector, keccak256("EXECUTOR_ROLE"), RANDOM_ADDRESS), bytes32(0), 0, TIMELOCK_MIN_DELAY);
        vm.warp(block.timestamp + TIMELOCK_MIN_DELAY);
        timelock.execute(address(timelock), 0, abi.encodeWithSelector(AccessControl.revokeRole.selector, keccak256("EXECUTOR_ROLE"), RANDOM_ADDRESS), bytes32(0), 0);
        vm.stopPrank();
        assertTrue(!timelock.hasRole(keccak256("EXECUTOR_ROLE"), RANDOM_ADDRESS));
    }
}
