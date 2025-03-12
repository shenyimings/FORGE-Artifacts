// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../yield/module/baseModule/BaseModuleBaseTest.t.sol";

contract RescuableRescueNativeTest is BaseModuleBaseTest {
    uint256 constant AMOUNT = 1000;

    function testCanRescueNative() public {
        uint256 ownerBalanceBefore = OWNER.balance;
        deal(address(baseModule), AMOUNT);
        assertEq(address(baseModule).balance, AMOUNT);
        vm.prank(OWNER);
        baseModule.rescueNative();
        assertEq(address(baseModule).balance, 0);
        assertEq(OWNER.balance - ownerBalanceBefore, AMOUNT);
    }

    function testOnlyOwnerCanRescueNative() public {
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        baseModule.rescueNative();
    }
}