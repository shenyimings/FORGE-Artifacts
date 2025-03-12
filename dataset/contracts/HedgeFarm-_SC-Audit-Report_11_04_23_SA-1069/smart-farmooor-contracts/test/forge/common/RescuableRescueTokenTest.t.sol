// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../yield/module/baseModule/BaseModuleBaseTest.t.sol";

contract RescuableRescueTokenTest is BaseModuleBaseTest {
    // NOTE: because the functions are internal we test them through the base module
    uint256 public AMOUNT = 1000;

    function testCanRescueToken() public {
        deal(BASE_TOKEN, address(baseModule), AMOUNT);
        assertEq(IERC20(BASE_TOKEN).balanceOf(address(baseModule)), AMOUNT);
        vm.startPrank(OWNER);
        baseModule.rescueToken(BASE_TOKEN);
        vm.stopPrank();
        assertEq(IERC20(BASE_TOKEN).balanceOf(address(baseModule)), 0);
        assertEq(IERC20(BASE_TOKEN).balanceOf(OWNER), AMOUNT);
    }

    function testOnlyOwnerCanRescueToken() public {
        address token = BASE_TOKEN;
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        baseModule.rescueToken(token);
    }
}