// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "./BaseTest.sol";
import "../src/core/NPVSwap.sol";
import "../src/liquidity/UniswapV3LiquidityPool.sol";
import "../src/interfaces/uniswap/ISwapRouter.sol";
import "../src/interfaces/uniswap/IUniswapV3Pool.sol";
import "../src/interfaces/uniswap/INonfungiblePositionManager.sol";

import { ILiquidityPool } from "../src/interfaces/ILiquidityPool.sol";

import "../src/interfaces/uniswap/IQuoterV2.sol";

contract EndToEndTest is BaseTest {

    function setUp() public {
        init();
    }

    function setUpAliceAddLiquidity(uint256 amount) public {
        // Alice: Get some NPV tokens so we can add liquidity
        vm.startPrank(alice);
        generatorToken.approve(address(npvSwap), 2000e18);
        npvSwap.lockForNPV(alice, alice, 2000e18, 10e18, new bytes(0));

        uint256 token0Amount = amount;
        uint256 token1Amount = amount;
        source.mintGenerator(alice, amount);
        source.mintYield(alice, amount);

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: uniswapV3Pool.token0(),
            token1: uniswapV3Pool.token1(),
            fee: 3000,
            tickLower: -1800,
            tickUpper: 2220,
            amount0Desired: token0Amount,
            amount1Desired: token1Amount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: alice,
            deadline: block.timestamp + 1 });

        IERC20(params.token0).approve(address(manager), token0Amount);
        IERC20(params.token1).approve(address(manager), token1Amount);
        manager.mint(params);
        vm.stopPrank();
    }

    function testSwapWithUniswapLiquidityPool() public {
        setUpAliceAddLiquidity(1e18);

        // Bob: Lock some future yield, and swap it for ETH
        vm.startPrank(bob);

        vm.expectRevert("NS: zero address");
        npvSwap.lockForNPV(address(0), bob, 200e18, 1e18, new bytes(0));

        vm.expectRevert("NS: zero address");
        npvSwap.lockForNPV(bob, address(0), 200e18, 1e18, new bytes(0));

        source.mintGenerator(bob, 1000000e18);
        generatorToken.approve(address(npvSwap), 200e18);
        assertEq(npvSwap.previewLockForNPV(200e18, 1e18), 653517780000000000);
        npvSwap.lockForNPV(bob, bob, 200e18, 1e18, new bytes(0));
        assertEq(IERC20(npvToken).balanceOf(bob), 653517780000000000);

        IERC20(npvToken).approve(address(pool), 5e17);
        uint256 before = IERC20(yieldToken).balanceOf(bob);
        uint256 out = pool.swap(bob, address(npvToken), 5e17, 0, 0);
        uint256 delta = IERC20(yieldToken).balanceOf(bob) - before;
        assertClose(delta, 5e17, 1e17);
        assertEq(out, 473692461556744701);
        assertEq(delta, 473692461556744701);

        vm.stopPrank();

        // Chad: Use ETH to buy future yield
        vm.startPrank(chad);

        source.mintYield(chad, 1000000e18);
        IERC20(yieldToken).approve(address(pool), 1e18);
        uint256 out2 = pool.swap(chad, address(yieldToken), 1e18, 0, 0);
        uint256 balance2 = IERC20(npvToken).balanceOf(chad);
        assertClose(balance2, 1e18, 5e17);
        assertEq(out2, 994537036467183765);
        assertEq(balance2, 994537036467183765);

        vm.expectRevert("NS: zero address");
        npvSwap.swapNPVForSlice(address(0), 99e16, new bytes(0));

        IERC20(npvToken).approve(address(npvSwap), 99e16);
        uint256 id = npvSwap.swapNPVForSlice(chad, 99e16, new bytes(0));
        (, , uint256 claimable1) = slice.generatedCredit(id);
        assertEq(claimable1, 0);

        vm.warp(block.timestamp + 0x1000);
        (uint256 nominal2, uint256 npv2, uint256 claimable2) = slice.generatedCredit(id);
        assertEq(nominal2, 5639479311486670);
        assertEq(npv2, 5639479311486670);
        assertEq(claimable2, 5639479311486670);

        vm.warp(block.timestamp + 0x80000);
        (uint256 nominal3, uint256 npv3, uint256 claimable3) = slice.generatedCredit(id);
        assertEq(nominal3, 727669107946584004);
        assertEq(npv3, 727669107946584004);
        assertEq(claimable3, 727669107946584004);

        vm.warp(block.timestamp + 0xf0000);
        (uint256 nominal4, uint256 npv4, uint256 claimable4) = slice.generatedCredit(id);
        assertEq(nominal4, 990000000000000000);
        assertEq(npv4, 99e16);
        assertEq(claimable4, 990000000000000000);

        uint256 before2 = yieldToken.balanceOf(chad);
        slice.claim(id, 0);
        assertEq(yieldToken.balanceOf(chad) - before2, claimable4);

        vm.stopPrank();
    }

    function testSwapWithDirectFunctions() public {
        setUpAliceAddLiquidity(1e18);

        // Bob locks and swaps generator tokens for upfront payment
        vm.startPrank(bob);

        source.mintGenerator(bob, 1000000e18);
        generatorToken.approve(address(npvSwap), 200e18);
        (uint256 preview, ) = npvSwap.previewLockForYield(200e18, 1e18, 0);
        assertEq(preview, 609815261420955817);
        assertClose(preview, 6e17, 1e17);

        {
            (uint256 quote ,) = npvSwap.previewSwapNPVForYield(657008058000000000, 0);
            assertEq(quote, 612862441028507418);
        }

        {
            (uint256 quote ,) = npvSwap.previewSwapNPVForYieldOut(609815261420955817, 0);
            assertEq(quote, 653517780000000000);
            assertEq(quote, npvSwap.previewLockForNPV(200e18, 1e18));
        }

        vm.expectRevert("NS: zero address");
        npvSwap.lockForYield(address(0), 200e18, 1e18, preview, 0, new bytes(0));

        (uint256 id1 , uint256 amount) = npvSwap.lockForYield(bob, 200e18, 1e18, preview, 0, new bytes(0));
        (address owner , , , , , , ) = npvSwap.slice().debtSlices(id1);
        assertEq(owner, bob);
        assertEq(amount, 609815261420955817);
        assertEq(yieldToken.balanceOf(bob), 609815261420955817);
        assertClose(amount, 6e17, 1e17);

        vm.stopPrank();

        // Chad swaps upfront yield for future yield
        vm.startPrank(chad);
        source.mintYield(chad, 1000000e18);
        (uint256 previewNpv, ) = npvSwap.previewSwapForSlice(1e18, 0);
        assertEq(previewNpv, 1023608343312813929);

        (uint256 npvOut, ) = npvSwap.previewSwapYieldForNPV(1e18, 0);
        assertEq(npvOut, 1023608343312813929);

        (uint256 yieldIn, ) = npvSwap.previewSwapYieldForNPVOut(npvOut, 0);
        assertEq(yieldIn, 1e18);

        vm.expectRevert("NS: zero address");
        npvSwap.swapForSlice(address(0), 1e18, previewNpv, 0, new bytes(0));

        IERC20(yieldToken).approve(address(npvSwap), 1e18);
        uint256 id = npvSwap.swapForSlice(chad, 1e18, previewNpv, 0, new bytes(0));

        vm.warp(block.timestamp + 0x1000);
        (uint256 nominal2, uint256 npv2, uint256 claimable2) = slice.generatedCredit(id);
        assertEq(nominal2, 5830927348664403);
        assertEq(npv2, 5830927348664403);
        assertEq(claimable2, 5830927348664403);

        vm.warp(block.timestamp + 0x80000);
        (uint256 nominal3, uint256 npv3, uint256 claimable3) = slice.generatedCredit(id);
        assertEq(nominal3, 752371888954662644);
        assertEq(npv3, 752371888954662644);
        assertEq(claimable3, 752371888954662644);

        vm.warp(block.timestamp + 0xf0000);
        (uint256 nominal4, uint256 npv4, uint256 claimable4) = slice.generatedCredit(id);
        assertEq(nominal4, 1023608343312813929);

        // NPV paid out should equal the preview
        assertEq(npv4, 1023608343312813929);
        assertEq(npv4, previewNpv);
        assertEq(claimable4, 1023608343312813929);

        vm.stopPrank();
    }

    function testNPVClaimableForExistingYield() public {
        // Add liquidity and move forward in time
        setUpAliceAddLiquidity(1e18);
        vm.warp(block.timestamp + 0x8000);
        slice.harvest();

        // Bob purchases future yield. Some should be immediately claimable.
        vm.startPrank(bob);
        source.mintYield(bob, 1000000e18);
        IERC20(yieldToken).approve(address(npvSwap), 1e18);
        (uint256 previewNpv, ) = npvSwap.previewSwapForSlice(5e17, 0);
        uint256 id = npvSwap.swapForSlice(bob, 5e17, previewNpv, 0, new bytes(0));
        vm.stopPrank();

        {
            (uint256 nominal, uint256 npv, uint256 claimable) = slice.generatedCredit(id);
            assertEq(nominal, 23750663505775351);
            assertEq(npv, 0);
            assertEq(claimable, 23750663505775351);
        }

        // Set yield rate to 0 and advance. No new yield, so claimable should stay flat.
        slice.recordData();
        source.setYieldPerBlock(0);
        vm.warp(block.timestamp + 0xf000);
        slice.recordData();

        {
            (uint256 nominal, uint256 npv, uint256 claimable) = slice.generatedCredit(id);
            assertEq(nominal, 23750663505775351);
            assertEq(npv, 0);
            assertEq(claimable, 23750663505775351);
        }

        // Resume yield generation
        slice.recordData();
        source.setYieldPerBlock(10000000000000);
        vm.warp(block.timestamp + 0xf00);
        slice.recordData();

        {
            (uint256 nominal, uint256 npv, uint256 claimable) = slice.generatedCredit(id);
            assertTrue(npv < nominal);
            assertEq(nominal,   26533304492071533);
            assertEq(npv,        2782640986296182);
            assertEq(claimable, 26533304492071533);
        }

        // Chad purchases some future yield. Some should be immediately available.
        vm.startPrank(chad);
        source.mintBoth(chad, 1000000e18);

        yieldToken.approve(address(npvSwap), 5e17);
        uint256 id2 = npvSwap.swapForSlice(chad, 5e17, 0, 0, new bytes(0));

        assertEq(previewNpv, 473692461556744701);

        vm.stopPrank();

        {
            (uint256 bNominal, uint256 bNpv, uint256 bClaimable) = slice.generatedCredit(id);
            (uint256 cNominal, uint256 cNpv, uint256 cClaimable) = slice.generatedCredit(id2);
            assertEq(bNominal, 26533304492071533);
            assertEq(bNpv, 2782640986296182);
            assertEq(bClaimable, 26533304492071533);

            assertEq(cNominal, 19354565733046043);
            assertEq(cNpv, 0);
            assertEq(cClaimable, 19354565733046043);
        }
    }

    function testPayOffWithYield() public {
        setUpAliceAddLiquidity(1e18);

        // Bob locks and swaps generator tokens for upfront payment
        vm.startPrank(bob);

        source.mintGenerator(bob, 200e18);
        generatorToken.approve(address(npvSwap), 200e18);
        uint256 id1 = npvSwap.slice().nextId();
        npvSwap.lockForYield(bob, 200e18, 1e18, 0, 0, new bytes(0));

        uint256 remainingNPV = npvSwap.slice().remaining(id1);

        uint256 part = remainingNPV / 10;

        // Pay part of it
        yieldToken.approve(address(npvSwap), part);
        npvSwap.mintAndPayWithYield(id1, part);

        vm.expectRevert("YS: npv debt");
        slice.unlockDebtSlice(id1);

        source.mintYield(bob, 1000000e18);
        uint256 rest = remainingNPV - part;
        yieldToken.approve(address(npvSwap), rest);

        npvSwap.mintAndPayWithYield(id1, rest);
        slice.unlockDebtSlice(id1);

        assertEq(generatorToken.balanceOf(bob), 200e18);

        vm.stopPrank();
    }


    function testPayOffWithYieldExtraAmount() public {
        setUpAliceAddLiquidity(1e18);

        // Bob locks and swaps generator tokens for upfront payment
        vm.startPrank(bob);

        source.mintGenerator(bob, 200e18);
        generatorToken.approve(address(npvSwap), 200e18);
        uint256 id1 = npvSwap.slice().nextId();

        npvSwap.lockForYield(bob, 200e18, 1e18, 0, 0, new bytes(0));

        uint256 remainingNPV = npvSwap.slice().remaining(id1);

        source.mintYield(bob, 1000000e18);

        // Pay part of it
        uint256 amount = remainingNPV + 10;
        yieldToken.approve(address(npvSwap), amount);
        uint256 before = yieldToken.balanceOf(bob);
        npvSwap.mintAndPayWithYield(id1, amount);

        slice.unlockDebtSlice(id1);

        assertEq(generatorToken.balanceOf(bob), 200e18);
        assertEq(yieldToken.balanceOf(bob), before - remainingNPV);

        vm.stopPrank();
    }

    function testRolloverForYield() public {
        setUpAliceAddLiquidity(5e18);

        // Bob locks and swaps generator tokens for upfront payment
        vm.startPrank(bob);

        source.mintGenerator(bob, 1000000e18);
        generatorToken.approve(address(npvSwap), 200e18);

        (uint256 id1 , uint256 amount) = npvSwap.lockForYield(bob, 200e18, 5e17, 0, 0, new bytes(0));
        assertEq(amount, 460271076128352010);
        assertEq(yieldToken.balanceOf(bob), 460271076128352010);

        (uint256 yieldOut, ) = npvSwap.previewRolloverForYield(id1, 1e18, 0);
        assertTrue(yieldOut < amount, "further in future less valuable");
        assertEq(yieldOut, 182486772273195556);

        vm.expectRevert("NS: zero address");
        npvSwap.rolloverForYield(id1, address(0), 1e18, 0, 0);

        slice.approveRollover(id1, address(npvSwap), 1);
        vm.expectRevert("YS: only owner or approved");
        npvSwap.rolloverForYield(id1, bob, 1e18, 0, 0);

        // Rollover with no time passing
        uint256 before = yieldToken.balanceOf(bob);
        slice.approveRollover(id1, address(npvSwap), 1e18);
        uint256 actualOut = npvSwap.rolloverForYield(id1, bob, 1e18, 0, 0);

        assertEq(actualOut, yieldOut);
        uint256 delta = yieldToken.balanceOf(bob) - before;
        assertEq(actualOut, delta);

        // Rollover after some time has passed
        vm.warp(block.timestamp + 4 days);

        (uint256 yieldOut2, ) = npvSwap.previewRolloverForYield(id1, 1e18, 0);
        assertEq(yieldOut2, 302868417388127250);

        slice.approveRollover(id1, address(0), 1e18);
        vm.expectRevert("YS: only owner or approved");
        npvSwap.rolloverForYield(id1, bob, 1e18, 0, 0);

        return;

        uint256 before2 = yieldToken.balanceOf(bob);
        slice.approveRollover(id1, address(npvSwap), 1e18);
        uint256 actualOut2 = npvSwap.rolloverForYield(id1, bob, 1e18, 0, 0);
        uint256 delta2 = yieldToken.balanceOf(bob) - before2;
        assertEq(actualOut2, delta2);
        assertEq(actualOut2, 302868417388127250);

        vm.stopPrank();
    }

    function testSwapRequire() public {
        setUpAliceAddLiquidity(1e18);

        ILiquidityPool pool = ILiquidityPool(npvSwap.pool());
        vm.expectRevert("ULP: zero address");
        pool.swap(address(0), address(yieldToken), 100, 0, 0);
        vm.expectRevert("ULP: this address");
        pool.swap(address(pool), address(yieldToken), 100, 0, 0);
    }
}
