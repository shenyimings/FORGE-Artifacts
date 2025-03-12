// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {Vester_BaseTest} from "./Vester_BaseTest.t.sol";

import {Vester} from "../../vesting/Vester.sol";

import {MockErc20} from "../mocks/MockERC20.sol";

import {Math} from "../../utils/Math.sol";

contract Vester_Vest is Vester_BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_WhenDurationIsValid_ShouldWork(uint256 duration) external {
        vm.assume(duration > 0);
        vm.assume(duration <= 31536000);
        esP88.approve(address(vester), 100 ether);
        vester.vestFor(address(this), 100 ether, duration);
        assertEq(esP88.balanceOf(address(this)), 0);

        uint256 userItemIndex = vester.nextItemId() - 1;

        (
            address owner,
            bool hasClaimed,
            uint256 amount,
            uint256 startTime,
            uint256 endTime
        ) = vester.items(userItemIndex);

        assertEq(owner, address(this));
        assertEq(amount, 100 ether);
        assertEq(endTime - startTime, duration);
        assertFalse(hasClaimed);
    }

    function testRevert_WhenZeroToken_ShouldRevert() external {
        esP88.approve(address(vester), 100 ether);
        vm.expectRevert(abi.encodeWithSignature("BadArgument()"));
        vester.vestFor(address(this), 0 ether, 31536001);
    }

    function testRevert_WhenDurationIsMoreThan1Year_ShouldRevert() external {
        esP88.approve(address(vester), 100 ether);
        vm.expectRevert(abi.encodeWithSignature("ExceedMaxDuration()"));
        vester.vestFor(address(this), 100 ether, 31536001);
    }
}
