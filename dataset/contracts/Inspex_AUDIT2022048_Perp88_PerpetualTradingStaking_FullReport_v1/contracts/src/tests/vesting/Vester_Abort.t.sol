// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {Vester_BaseTest} from "./Vester_BaseTest.t.sol";

import {Vester} from "../../vesting/Vester.sol";

import {MockErc20} from "../mocks/MockERC20.sol";

import {Math} from "../../utils/Math.sol";

contract Vester_Abort is Vester_BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testCorrectness_WhenVestHasNotCompleted_ShouldWork() external {
        esP88.approve(address(vester), 100 ether);
        vester.vestFor(address(this), 100 ether, 31536000);

        uint256 userItemIndex = vester.nextItemId() - 1;

        vm.warp(block.timestamp + 11536000);
        vester.abort(userItemIndex);
        assertEq(esP88.balanceOf(address(this)), 100 ether);
    }

    function testCorrectness_WhenCalledFromNonOwner_ShouldRevert() external {
        esP88.approve(address(vester), 100 ether);
        vester.vestFor(address(this), 100 ether, 31536000);

        uint256 userItemIndex = vester.nextItemId() - 1;

        vm.prank(address(1234), address(1234));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        vester.abort(userItemIndex);
    }

    function testCorrectness_WhenVestHasCompletedButNotClaimed_ShouldWork() external {
        esP88.approve(address(vester), 100 ether);
        vester.vestFor(address(this), 100 ether, 31536000);

        uint256 userItemIndex = vester.nextItemId() - 1;

        vm.warp(block.timestamp + 31536000);
        vester.abort(userItemIndex);

        assertEq(esP88.balanceOf(address(this)), 100 ether);
    }

    function testRevert_WhenAlreadyClaimed_ShouldRevert() external {
        esP88.approve(address(vester), 100 ether);
        vester.vestFor(address(this), 100 ether, 31536000);

        uint256 userItemIndex = vester.nextItemId() - 1;

        vm.warp(block.timestamp + 31536000);
        vester.claimFor(address(this), userItemIndex);

        vm.expectRevert(abi.encodeWithSignature("Claimed()"));
        vester.abort(userItemIndex);
    }
}
