// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SmartFarmooorBasicTestHelperAvax.t.sol";

contract SmartFarmooorRescueTest is SmartFarmooorBasicTestHelperAvax {

    function testCanRescueToken() public {
        deal(JOE, address(smartFarmooor), DEPOSIT_AMOUNT);
        assertEq(IERC20(JOE).balanceOf(address(smartFarmooor)), DEPOSIT_AMOUNT);
        vm.startPrank(address(timelock));
        smartFarmooor.rescueToken(JOE);
        vm.stopPrank();
        assertEq(IERC20(JOE).balanceOf(address(smartFarmooor)), 0);
        assertEq(IERC20(JOE).balanceOf(address(timelock)), DEPOSIT_AMOUNT);
    }

    function testOnlyOwnerCanRescueToken() public {
        address token = WAVAX;
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"));
        smartFarmooor.rescueToken(token);
    }

    function testCanRescueNative() public {
        uint256 ownerBalanceBefore = address(timelock).balance;
        deal(address(smartFarmooor), DEPOSIT_AMOUNT);
        assertEq(address(smartFarmooor).balance, DEPOSIT_AMOUNT);
        vm.prank(address(timelock));
        smartFarmooor.rescueNative();
        assertEq(address(smartFarmooor).balance, 0);
        assertEq(address(timelock).balance - ownerBalanceBefore, DEPOSIT_AMOUNT);
    }

    function testOnlyOwnerCanRescueNative() public {
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("AccessControl: account 0x305ad87a471f49520218feaf4146e26d9f068eb4 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"));
        smartFarmooor.rescueNative();
    }
}
