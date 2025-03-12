// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./StargateBaseTest.t.sol";

contract StargateSetRedeemFromChainIdTest is StargateBaseTest {

    function testCanSetRedeemFromChainId() public {
        vm.prank(OWNER);
        stargateYieldModule.setRedeemFromChainId(42);
        assertEq(stargateYieldModule.redeemFromChainId(), 42);
    }

    function testOnlyOwnerCanSetRedeemFromChainId() public {
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("BaseModule: only manager or owner"));
        stargateYieldModule.setRedeemFromChainId(42);
    }

    function testCanSetRedeemFromChainIdWithTimelock() public {
        _transferOwnershipToTimelock();

        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("BaseModule: only manager or owner"));
        stargateYieldModule.setRedeemFromChainId(42);

        vm.prank(OWNER);
        vm.expectRevert(bytes("BaseModule: only manager or owner"));
        stargateYieldModule.setRedeemFromChainId(42);

        vm.prank(address(timelock));
        stargateYieldModule.setRedeemFromChainId(42);

        vm.startPrank(OWNER);
        bytes32 id = timelock.hashOperation(address(stargateYieldModule), 0, abi.encodeWithSelector(StargateYieldModule.setRedeemFromChainId.selector, 43), bytes32(0), 0);
        assertEq(timelock.isOperation(id), false);
        timelock.schedule(address(stargateYieldModule), 0, abi.encodeWithSelector(StargateYieldModule.setRedeemFromChainId.selector, 43), bytes32(0), 0, TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperation(id), true);
        assertEq(timelock.isOperationPending(id), true);
        assertEq(timelock.isOperationReady(id), false);
        assertEq(timelock.isOperationDone(id), false);
        vm.warp(block.timestamp + TIMELOCK_MIN_DELAY);
        assertEq(timelock.isOperationReady(id), true);
        assertEq(timelock.isOperationDone(id), false);
        timelock.execute(address(stargateYieldModule), 0, abi.encodeWithSelector(StargateYieldModule.setRedeemFromChainId.selector, 43), bytes32(0), 0);
        assertEq(timelock.isOperationDone(id), true);
        vm.stopPrank();
        assertEq(stargateYieldModule.redeemFromChainId(), 43);
    }
}
