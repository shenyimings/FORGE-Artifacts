// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseTest } from "./BaseTest.sol";

import { FakeToken } from "./helpers/FakeToken.sol";
import { FakeYieldTracker } from "./helpers/FakeYieldTracker.sol";

contract FakeYieldTrackerTest is BaseTest {

    function testYieldSource() public {
        FakeYieldTracker source = new FakeYieldTracker(200);

        address user0 = createTestUser(0);
        assertEq(source.amountPending(user0), 0);

        source.mintGenerator(user0, 10);
        assertEq(source.amountPending(user0), 0);

        vm.roll(block.number + 1);
        assertEq(source.amountPending(user0), 2000);

        vm.prank(user0);
        source.harvest();
        assertEq(source.amountPending(user0), 0);
        assertEq(FakeToken(source.yieldToken()).balanceOf(user0), 2000);

        address user1 = createTestUser(1);
        assertEq(source.amountPending(user1), 0);

        vm.roll(block.number + 1);
        assertEq(source.amountPending(user1), 0);

        source.mintGenerator(user1, 50);
        assertEq(source.amountPending(user1), 0);

        vm.roll(block.number + 1);
        assertEq(source.amountPending(user0), 4000);
        assertEq(source.amountPending(user1), 10000);

        vm.prank(user0);
        source.harvest();
        vm.prank(user1);
        source.harvest();

        assertEq(FakeToken(source.yieldToken()).balanceOf(user0), 6000);
        assertEq(FakeToken(source.yieldToken()).balanceOf(user1), 10000);
    }

    function testChangingYieldRate() public {
        FakeYieldTracker source = new FakeYieldTracker(200);

        address user0 = createTestUser(0);

        assertEq(source.amountPending(user0), 0);


        source.mintGenerator(user0, 10);
        assertEq(source.amountPending(user0), 0);

        vm.roll(block.number + 1);
        assertEq(source.amountPending(user0), 2000);

        vm.roll(block.number + 1);
        assertEq(source.amountPending(user0), 4000);

        source.setYieldPerBlock(100);
        assertEq(source.amountPending(user0), 4000);

        vm.roll(block.number + 1);
        assertEq(source.amountPending(user0), 5000);

        address user1 = createTestUser(1);
        source.mintGenerator(user1, 30);
        assertEq(source.amountPending(user1), 0);

        vm.roll(block.number + 1);
        assertEq(source.amountPending(user0), 6000);
        assertEq(source.amountPending(user1), 3000);

        vm.prank(user0);
        source.harvest();
        vm.prank(user1);
        source.harvest();

        assertEq(FakeToken(source.yieldToken()).balanceOf(user0), 6000);
        assertEq(FakeToken(source.yieldToken()).balanceOf(user1), 3000);
    }
}
