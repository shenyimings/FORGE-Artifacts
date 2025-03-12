// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../contracts/Booster.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

contract BoosterPolygonTest is Test {
    address strategy1 = 0x7f5c579bFD63455580B50Eb8714433caBfBd0C1C;
    address logic1 = 0x0c561B41d63eE6B3E6f4aECC6c6B6b0D0a48aC4D;
    address strategy2 = 0xF2d48F281393CFc6f5e4A7327E13e174e55dB418;
    address logic2 = 0xfb67473C8725C37eD8bc330d9F9a13bB91C545F5;
    address boosting = 0xbC70F9E663F4b79De2DaFeD45EB524fe1356AC3e;
    address blid = 0x4b27Cd6E6a5E83d236eAD376D256Fe2F9e9f0d2E;

    uint256 private mainnetFork;

    Booster public booster;

    uint256 private constant BLOCK_NUMBER = 44637519;

    function setUp() public {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("polygon"), BLOCK_NUMBER);

        vm.startPrank(address(0));
        booster = new Booster();
        booster.__Booster_init();

        booster.setBLID(blid);
        booster.setBoostingAddress(boosting);
        vm.stopPrank();

        vm.startPrank(boosting);
        IERC20MetadataUpgradeable(blid).approve(
            address(booster),
            type(uint256).max
        );
        vm.stopPrank();
    }

    function testAddEarn() public {
        uint256 blidBefore1;
        uint256 blidAfter1;
        uint256 blidBefore2;
        uint256 blidAfter2;

        vm.startPrank(address(0));

        // Set BlidPerDay for each strategy
        booster.setBlidPerDay(strategy1, 10**18);
        booster.setBlidPerDay(strategy2, 10**17);

        assertEq(booster.blidPerDayPerStrategy(strategy1), 10**18);
        assertEq(booster.blidPerDayPerStrategy(strategy2), 10**17);

        // First add Earn without any earning
        blidBefore1 = IERC20MetadataUpgradeable(blid).balanceOf(logic1);
        blidBefore2 = IERC20MetadataUpgradeable(blid).balanceOf(logic2);

        booster.addEarn(strategy1);
        booster.addEarn(strategy2);

        blidAfter1 = IERC20MetadataUpgradeable(blid).balanceOf(logic1);
        blidAfter2 = IERC20MetadataUpgradeable(blid).balanceOf(logic2);

        assertEq(blidBefore1, blidAfter1);
        assertEq(blidBefore2, blidAfter2);

        // Second addEarn 2 days after, blidAmount = 2 ether
        vm.warp(block.timestamp + 86400 + 86400);
        vm.roll(block.number + 30000);

        booster.addEarn(strategy1);
        blidBefore1 = blidAfter1;
        blidAfter1 = IERC20MetadataUpgradeable(blid).balanceOf(logic1);
        assertEq(blidBefore1 + 2 * 10**18, blidAfter1);

        booster.addEarn(strategy2);
        blidBefore2 = blidAfter2;
        blidAfter2 = IERC20MetadataUpgradeable(blid).balanceOf(logic2);
        assertEq(blidBefore2 + 2 * 10**17, blidAfter2);

        // Third addEarn 10 days after, blidAmount = 10 ether
        vm.warp(block.timestamp + 86400 * 10);
        vm.roll(block.number + 30000);

        booster.addEarn(strategy1);
        blidBefore1 = blidAfter1;
        blidAfter1 = IERC20MetadataUpgradeable(blid).balanceOf(logic1);
        assertEq(blidBefore1 + 10 * 10**18, blidAfter1);

        booster.addEarn(strategy2);
        blidBefore2 = blidAfter2;
        blidAfter2 = IERC20MetadataUpgradeable(blid).balanceOf(logic2);
        assertEq(blidBefore2 + 10 * 10**17, blidAfter2);

        vm.stopPrank();
    }
}
