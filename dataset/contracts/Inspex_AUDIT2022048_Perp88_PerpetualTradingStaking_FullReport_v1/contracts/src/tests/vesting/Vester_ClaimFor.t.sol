// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {Vester_BaseTest} from "./Vester_BaseTest.t.sol";
import {Vester} from "../../vesting/Vester.sol";

import {MockErc20} from "../mocks/MockERC20.sol";

import {Math} from "../../utils/Math.sol";

contract Vester_ClaimFor is Vester_BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testCorrectness_WhenVestHasCompleted_ShouldWork() external {
        esP88.approve(address(vester), 100 ether);
        vester.vestFor(address(this), 100 ether, 30000000);

        uint256 userItemIndex = vester.nextItemId() - 1;

        uint256 expectedP88Amount = vester.getUnlockAmount(100 ether, 30000000);

        vm.warp(block.timestamp + 31536000);
        vester.claimFor(address(this), userItemIndex);

        assertEq(p88.balanceOf(address(this)), expectedP88Amount);
        assertEq(esP88.balanceOf(BURN_ADDRESS), expectedP88Amount);
        assertEq(
            esP88.balanceOf(TREASURY_ADDRESS),
            100 ether - expectedP88Amount
        );
    }

    function testCorrectness_WhenAllVestHasCompleted_ShouldWork() external {
        uint256[] memory indexes = new uint256[](2);

        esP88.approve(address(vester), 100 ether);

        vester.vestFor(address(this), 50 ether, 30000000);
        indexes[0] = vester.nextItemId() - 1;

        vester.vestFor(address(this), 50 ether, 30000000);
        indexes[1] = vester.nextItemId() - 1;

        uint256 expectedP88Amount = vester.getUnlockAmount(100 ether, 30000000);

        vm.warp(block.timestamp + 31536000);
        vester.claimFor(address(this), indexes);

        assertEq(p88.balanceOf(address(this)), expectedP88Amount);
        assertEq(esP88.balanceOf(BURN_ADDRESS), expectedP88Amount);
        assertEq(
            esP88.balanceOf(TREASURY_ADDRESS),
            100 ether - expectedP88Amount
        );
    }

    function testRevert_WhenOwnerAndDestinationAreDifferent_ShouldRevert()
        external
    {
        esP88.approve(address(vester), 100 ether);
        vester.vestFor(address(this), 100 ether, 31536000);

        uint256 userItemIndex = vester.nextItemId() - 1;

        vm.warp(block.timestamp + 31536000);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        vester.claimFor(address(1), userItemIndex);
    }

    function testRevert_WhenVestHasNotCompleted_ShouldRevert() external {
        esP88.approve(address(vester), 100 ether);
        vester.vestFor(address(this), 100 ether, 31536000);

        uint256 userItemIndex = vester.nextItemId() - 1;

        vm.expectRevert(abi.encodeWithSignature("HasNotCompleted()"));
        vester.claimFor(address(this), userItemIndex);
    }

    function testRevert_ItemHasBeenClaimed_ShouldRevert()
        external
    {
        esP88.approve(address(vester), 100 ether);
        vester.vestFor(address(this), 100 ether, 31536000);

        uint256 userItemIndex = vester.nextItemId() - 1;

        vm.warp(block.timestamp + 31536000);
        vester.claimFor(address(this), userItemIndex);

        vm.expectRevert(abi.encodeWithSignature("Claimed()"));
        vester.claimFor(address(this), userItemIndex);
    }

}
