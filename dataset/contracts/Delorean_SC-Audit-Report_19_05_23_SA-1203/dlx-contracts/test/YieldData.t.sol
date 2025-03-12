// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseTest.sol";
import "../src/data/YieldData.sol";

contract YieldDataTest is BaseTest {

    YieldData public data;
    address public user0;

    function setUp() public {
        user0 = createUser(0);
        data = new YieldData(20);
        data.setWriter(user0);
    }
    
    function testSimpleData() public {
        assertEq(data.yieldPerTokenPerSecond(1, 1, 0, 0), 0);
        assertEq(data.yieldPerTokenPerSecond(uint128(block.timestamp), uint128(block.timestamp) + 1, 0, 0), 0);

        vm.startPrank(user0);
        data.record(10e18, 0);
        vm.roll(block.number + 20);
        vm.warp(block.timestamp + 20);
        data.record(10e18, 5000);
        assertEq(data.yieldPerTokenPerSecond(uint32(block.timestamp) - 20, uint32(block.timestamp), 0, 0), 25);
        vm.stopPrank();

        assertEq(data.isEmpty(), false);

        YieldData.Epoch memory current = data.current();
        assertEq(current.tokens, 10e18);
        assertEq(current.yield, 5000);
        assertEq(current.yieldPerToken, 0);
        assertEq(current.blockTimestamp, 21);
        assertEq(current.epochSeconds, 0);
    }

    function testSetWriterChecks() public {
        vm.expectRevert("YD: only set once");
        data.setWriter(createUser(1));
        vm.stopPrank();

        vm.expectRevert("YD: only writer");
        data.record(1, 2);

        vm.expectRevert("YD: zero address");
        data.setWriter(address(0));
    }

    function testDataChecks() public {
        assertEq(data.isEmpty(), true);

        vm.warp(3);

        vm.expectRevert("YD: no epochs");
        data.yieldPerTokenPerSecond(1, 3, 0, 0);

        vm.expectRevert("YD: end must be in the past or current");
        data.yieldPerTokenPerSecond(1, 10, 0, 0);

        vm.expectRevert("YD: start must be in the past");
        data.yieldPerTokenPerSecond(4, 5, 0, 0);

        vm.expectRevert("YD: start must precede end");
        data.yieldPerTokenPerSecond(5, 4, 0, 0);
    }

    function testZeroYield() public {
        assertEq(data.yieldPerTokenPerSecond(1, 1, 0, 0), 0);
        assertEq(data.yieldPerTokenPerSecond(uint128(block.timestamp), uint128(block.timestamp) + 1, 0, 0), 0);

        vm.startPrank(user0);
        data.record(10e18, 0);
        vm.roll(block.number + 20);
        vm.warp(block.timestamp + 20);
        assertEq(data.yieldPerTokenPerSecond(uint32(block.timestamp) - 20, uint32(block.timestamp), 10e18, 0), 0);
        vm.stopPrank();
    }

    function testSplitEpoch() public {
        vm.startPrank(user0);
        data.record(10e18, 0);
        vm.warp(block.timestamp + 1);
        data.record(20e18, 20000);
        vm.warp(block.timestamp + 7);
        data.record(20e18, 280000);

        assertEq(data.yieldPerTokenPerSecond(uint32(block.timestamp) - 8, uint32(block.timestamp), 0, 0), 1875);
        vm.stopPrank();
    }

    function testMultipleEpochs() public {
        vm.startPrank(user0);
        data.record(10e18, 0);
        vm.warp(block.timestamp + 20);
        data.record(10e18, 5000);

        vm.warp(block.timestamp + 20);
        data.record(10e18, 15000);

        vm.warp(block.timestamp + 20);
        data.record(10e18, 55000);

        assertEq(data.yieldPerTokenPerSecond(uint32(block.timestamp) - 60, uint32(block.timestamp) - 40, 0, 0), 25);
        assertEq(data.yieldPerTokenPerSecond(uint32(block.timestamp) - 40, uint32(block.timestamp) - 20, 0, 0), 50);
        assertEq(data.yieldPerTokenPerSecond(uint32(block.timestamp) - 20, uint32(block.timestamp), 0, 0), 200);
        assertEq(data.yieldPerTokenPerSecond(uint32(block.timestamp) - 60, uint32(block.timestamp) - 20, 0, 0), (25 + 50) >> 1);
        assertEq(data.yieldPerTokenPerSecond(uint32(block.timestamp) - 50, uint32(block.timestamp) - 20, 0, 0), 41);
        assertEq(data.yieldPerTokenPerSecond(uint32(block.timestamp) - 50, uint32(block.timestamp) - 10, 0, 0), 81);
        vm.stopPrank();
    }

    function testManyDifferentEpochs() public {
        vm.startPrank(user0);
        data.record(10e18, 0);
        uint32 startBlockNumber = uint32(block.timestamp);
        for (uint256 i = 0; i < 100; i++) {
            vm.warp(block.timestamp + 20);
            data.record(10e18, (i+1) * (i+1) * 10e2);
        }

        assertEq(data.yieldPerTokenPerSecond(startBlockNumber, startBlockNumber + 20, 0, 0), 5);
        assertEq(data.yieldPerTokenPerSecond(startBlockNumber + 20, startBlockNumber + 40, 0, 0), 15);
        assertEq(data.yieldPerTokenPerSecond(startBlockNumber + 40, startBlockNumber + 60, 0, 0), 25);
        assertEq(data.yieldPerTokenPerSecond(startBlockNumber + 1800, startBlockNumber + 1820, 0, 0), 905);
        assertEq(data.yieldPerTokenPerSecond(startBlockNumber + 200, startBlockNumber + 1820, 0, 0), 505);
        vm.stopPrank();
    }

    function testValidateStartAndEnd() public {
        vm.startPrank(user0);
        data.record(10e18, 0);
        uint32 startBlockNumber = uint32(block.timestamp);
        for (uint256 i = 0; i < 100; i++) {
            vm.warp(block.timestamp + 20);
            data.record(10e18, (i+1) * (i+1) * 10e2);
        }

        vm.expectRevert("YD: start must precede end");
        data.yieldPerTokenPerSecond(startBlockNumber + 20, startBlockNumber, 0, 0);
        vm.stopPrank();
    }
}
