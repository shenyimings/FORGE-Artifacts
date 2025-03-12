// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./BaseTest.sol";
import "./helpers/FakeToken.sol";
import "./helpers/FakeYieldSource.sol";
import "../src/tokens/NPVToken.sol";
import "../src/core/YieldSlice.sol";
import "../src/core/NPVSwap.sol";
import "../src/data/Discounter.sol";
import "../src/data/YieldData.sol";

contract YieldSliceTest is BaseTest {
    function setUp() public {
    }

    function debtSliceNPVDebt(uint256 id) internal view returns (uint256) {
        ( , , , , , uint256 npvDebt, ) = slice.debtSlices(id);
        return npvDebt;
    }

    function creditSliceNPVCredit(uint256 id) internal view returns (uint256) {
        ( , , , uint256 npvCredit, , , , ) = slice.creditSlices(id);
        return npvCredit;
    }

    function creditSliceNPVTokens(uint256 id) internal view returns (uint256) {
        ( , , , , uint256 npvTokens, , , ) = slice.creditSlices(id);
        return npvTokens;
    }

    function testSimpleSale() public {
        init(10000000000);
        discounter.setMaxDays(1440);

        vm.startPrank(alice);

        uint256 id1 = slice.nextId();

        uint256 before = generatorToken.balanceOf(alice);
        generatorToken.approve(address(npvSwap), 200e18);
        npvSwap.lockForNPV(alice, alice, 200e18, 1e18, new bytes(0));
        uint256 afterVal = generatorToken.balanceOf(alice);
        assertEq(before - afterVal, 200e18);

        assertEq(discounter.discounted(200e18, 1e18), 877248880000000000);
        assertEq(npvToken.balanceOf(alice), 877248880000000000);
        assertEq(debtSliceNPVDebt(id1), 877248880000000000);

        vm.expectRevert("YS: npv debt");
        slice.unlockDebtSlice(id1);

        for (uint256 day = 0; day < 100; day += 7) {
            vm.warp(block.timestamp + 7 days);
            slice.recordData();
        }
        vm.expectRevert("YS: npv debt");
        slice.unlockDebtSlice(id1);

        for (uint256 day = 0; day < 100; day += 7) {
            vm.warp(block.timestamp + 7 days);
            slice.recordData();
        }
        vm.expectRevert("YS: npv debt");
        slice.unlockDebtSlice(id1);

        for (uint256 day = 0; day < 1240; day += 7) {
            vm.warp(block.timestamp + 7 days);
            slice.recordData();
        }

        assertEq(slice.tokens(id1), 200e18);

        slice.unlockDebtSlice(id1);
        assertEq(generatorToken.balanceOf(alice), before);
        assertEq(slice.totalShares(), 0);
        assertEq(slice.tokens(id1), 0);

        vm.expectRevert("YS: already unlocked");
        slice.unlockDebtSlice(id1);

        slice.harvest();

        (uint256 nominal1, uint256 npv1, uint256 refund1) = slice.generatedDebt(id1);

        assertTrue(yieldToken.balanceOf(address(slice)) > npvToken.balanceOf(alice),
                   "nominal should exceed npv");
        assertTrue(yieldToken.balanceOf(address(slice)) > 1e18,
                   "nominal should exceed sold");
        assertEq(yieldToken.balanceOf(address(slice)), 1242411134394522683);

        assertClose(yieldToken.balanceOf(address(slice)), nominal1, 1e12);
        assertEq(npv1, 877248880000000000);
        assertEq(refund1, 15572865605477317);

        vm.warp(uint256(block.timestamp + 0x1000));
        (uint256 nominal2, uint256 npv2, ) = slice.generatedDebt(id1);
        assertEq(nominal1, nominal2);
        assertEq(npv1, npv2);

        vm.stopPrank();
    }

    function testSaleForGasReport() public {
        init();

        uint256 numDays = discounter.MAX_DAYS_LIMIT();
        uint256 amountGenerator = 5e9;
        uint256 amountYield = 10e18;
        uint256 yieldPerSecond = amountYield / (numDays * 1 days);
        discounter.setMaxDays(numDays);

        uint256 ratio = numDays / (discounter.discountPeriod() / 1 days);
        assertEq(ratio, discounter.DISCOUNT_PERIODS_LIMIT());

        discounter.setDaily(yieldPerSecond * 1 days * 1e18 / amountGenerator);

        source.setYieldPerBlock(yieldPerSecond);

        vm.startPrank(alice);

        uint256 id1 = slice.nextId();

        generatorToken.approve(address(npvSwap), amountGenerator);
        npvSwap.lockForNPV(alice, alice, amountGenerator, amountYield, new bytes(0));

        vm.expectRevert("YS: npv debt");
        slice.unlockDebtSlice(id1);

        for (uint256 day = 0; day < 70; day += 7) {
            vm.warp(block.timestamp + 7 days);
            slice.recordData();
        }
        vm.expectRevert("YS: npv debt");
        slice.unlockDebtSlice(id1);

        for (uint256 day = 0; day < 100; day += 7) {
            vm.warp(block.timestamp + 7 days);
            slice.recordData();
        }
        vm.expectRevert("YS: npv debt");
        slice.unlockDebtSlice(id1);

        for (uint256 day = 0; day < numDays; day += 7) {
            vm.warp(block.timestamp + 7 days);
            slice.recordData();
        }

        slice.unlockDebtSlice(id1);

        slice.harvest();

        vm.stopPrank();
    }

    function testTwoSales() public {
        init(10000000000);
        discounter.setMaxDays(1440);

        vm.startPrank(alice);

        uint256 id1 = slice.nextId();

        uint256 before = generatorToken.balanceOf(alice);
        generatorToken.approve(address(npvSwap), 200e18);
        npvSwap.lockForNPV(alice, alice, 200e18, 1e18, new bytes(0));
        uint256 afterVal = generatorToken.balanceOf(alice);
        assertEq(before - afterVal, 200e18);

        assertEq(discounter.discounted(200e18, 1e18), 877248880000000000);
        assertEq(npvToken.balanceOf(alice), 877248880000000000);
        assertEq(debtSliceNPVDebt(id1), 877248880000000000);

        vm.expectRevert("YS: npv debt");
        slice.unlockDebtSlice(id1);

        for (uint256 day = 0; day < 100; day += 7) {
            vm.warp(block.timestamp + 7 days);
            slice.recordData();
        }
        vm.expectRevert("YS: npv debt");
        slice.unlockDebtSlice(id1);

        for (uint256 day = 0; day < 100; day += 7) {
            vm.warp(block.timestamp + 7 days);
            slice.recordData();
        }
        vm.expectRevert("YS: npv debt");
        slice.unlockDebtSlice(id1);

        vm.stopPrank();

        source.mintBoth(bob, 1000000e18);

        // Values are regression tests for shift NPV logic
        assertEq(creditSliceNPVCredit(slice.UNALLOC_ID()), 877248880000000000);
        uint256 beforeBob = generatorToken.balanceOf(bob);

        vm.startPrank(bob);
        generatorToken.approve(address(npvSwap), 40e18);
        uint256 id2 = npvSwap.lockForNPV(bob, bob, 40e18, 1e17, new bytes(0));
        vm.stopPrank();
        assertEq(creditSliceNPVCredit(slice.UNALLOC_ID()), 888444683624298764);

        for (uint256 day = 0; day < 2000; day += 7) {
            vm.warp(block.timestamp + 7 days);
            slice.recordData();
        }

        vm.startPrank(alice);
        slice.unlockDebtSlice(id1);
        assertEq(generatorToken.balanceOf(alice), before);
        vm.stopPrank();

        vm.startPrank(bob);
        slice.unlockDebtSlice(id2);
        assertEq(generatorToken.balanceOf(bob), beforeBob);
        vm.stopPrank();

        slice.harvest();

        {
            (uint256 nominal1, uint256 npv1, uint256 refund1) = slice.generatedDebt(id1);
            (, uint256 npv2, uint256 refund2) = slice.generatedDebt(id2);

            assertEq(npv1,    877248880000000000);
            assertEq(refund1, 288771476913184587);

            assertEq(npv2,    93232852000000000);
            assertEq(refund2, 174383317123062844);

            vm.warp(uint256(block.timestamp + 0x1000));
            (uint256 nominal1_2, uint256 npv1_2, ) = slice.generatedDebt(id1);
            assertEq(nominal1, nominal1_2);
            assertEq(npv1, npv1_2);
        }
    }

    function testUnlockRole() public {
        init(10000000000);
        discounter.setMaxDays(1440);

        vm.startPrank(alice);
        uint256 id1 = slice.nextId();
        generatorToken.approve(address(npvSwap), 200e18);
        npvSwap.lockForNPV(alice, alice, 200e18, 1e18, new bytes(0));

        vm.expectRevert("YS: npv debt");
        slice.unlockDebtSlice(id1);

        vm.stopPrank();

        vm.warp(block.timestamp + 1440 days);

        vm.startPrank(bob);
        vm.expectRevert("YS: only owner or unlocker");
        slice.unlockDebtSlice(id1);
        vm.stopPrank();

        slice.setUnlocker(bob);

        vm.startPrank(bob);
        vm.expectRevert("YS: only gov");
        slice.setUnlocker(bob);

        slice.unlockDebtSlice(id1);

        vm.stopPrank();
    }

    function testTransferSlice() public {
        init(10000000000);
        discounter.setMaxDays(1440);

        vm.startPrank(alice);

        uint256 id1 = slice.nextId();

        uint256 before = generatorToken.balanceOf(alice);
        generatorToken.approve(address(npvSwap), 200e18);
        npvSwap.lockForNPV(alice, alice, 200e18, 1e18, new bytes(0));
        uint256 afterVal = generatorToken.balanceOf(alice);
        uint256 npvSliced = 877248880000000000;
        assertEq(npvToken.balanceOf(alice), npvSliced);
        npvToken.transfer(chad, npvSliced);
        assertEq(before - afterVal, 200e18);

        vm.expectRevert("YS: invalid id");
        slice.transferOwnership(999, alice);
        vm.expectRevert("YS: zero address");
        slice.transferOwnership(id1, address(0));
        vm.expectRevert("YS: this address");
        slice.transferOwnership(id1, address(slice));
        vm.expectRevert("YS: transfer owner");
        slice.transferOwnership(id1, alice);

        slice.transferOwnership(id1, bob);

        vm.stopPrank();

        vm.expectRevert("YS: only debt slice owner");
        slice.transferOwnership(id1, alice);

        // Warp forward 700 days, about halfway through generating the sold yield
        for (uint256 i = 0; i < 700; i += 7) {
            slice.recordData();
            vm.warp(block.timestamp + 7 days);
        }

        // Chad buys yield, transfer slice to Degen
        vm.startPrank(chad);
        npvToken.approve(address(npvSwap), npvSliced);
        uint256 id2 = npvSwap.swapNPVForSlice(chad, npvSliced, new bytes(0));

        assertEq(yieldToken.balanceOf(chad), 0);
        assertEq(yieldToken.balanceOf(degen), 0);
        slice.transferOwnership(id2, degen);
        assertEq(yieldToken.balanceOf(chad), 604799989957108597);
        assertEq(yieldToken.balanceOf(degen), 0);
        vm.expectRevert("YS: transfer owner");
        slice.transferOwnership(id2, degen);
        vm.stopPrank();

        vm.expectRevert("YS: only credit slice owner");
        slice.transferOwnership(id2, bob);

        // Warp forward 400 days, transfer the credit slice again
        for (uint256 i = 0; i < 400; i += 7) {
            slice.recordData();
            vm.warp(block.timestamp + 7 days);
        }

        vm.startPrank(degen);
        assertEq(yieldToken.balanceOf(degen), 0);
        assertEq(yieldToken.balanceOf(eve), 0);
        slice.transferOwnership(id2, eve);
        assertEq(yieldToken.balanceOf(degen), 350783989975122986);
        assertEq(yieldToken.balanceOf(eve), 0);
        vm.stopPrank();

        // Warp forward 400 days, completing generation of the sold yield
        for (uint256 i = 0; i < 400; i += 7) {
            slice.recordData();
            vm.warp(block.timestamp + 7 days);
        }

        vm.startPrank(degen);
        vm.expectRevert("YS: only owner");
        slice.claim(id2, 0);
        vm.stopPrank();

        vm.startPrank(eve);
        assertEq(yieldToken.balanceOf(eve), 0);
        slice.claim(id2, 0);
        assertEq(yieldToken.balanceOf(eve), 282860258613110012);
        vm.stopPrank();

        // All the yield has been generated, so Bob (debt slice transfer beneficiary)
        // should be able to unlock and receive the generator tokens
        vm.startPrank(bob);
        assertEq(generatorToken.balanceOf(bob), 0);
        slice.unlockDebtSlice(id1);
        assertEq(generatorToken.balanceOf(bob), 200e18);
        vm.stopPrank();

        assertEq(yieldToken.balanceOf(chad) +
                 yieldToken.balanceOf(degen) +
                 yieldToken.balanceOf(eve),
                 1238444238545341595);
    }

    function testTransferSliceReverts() public {
        vm.expectRevert();
        slice.transferOwnership(3333333, alice);
        
        vm.expectRevert();
        slice.transferOwnership(3333333, address(0));

        vm.expectRevert();
        slice.transferOwnership(3333333, address(slice));
    }

    function testUnlockWithNPVTokens() public {
        init();

        vm.startPrank(alice);

        uint256 id1 = slice.nextId();

        uint256 before = generatorToken.balanceOf(alice);
        generatorToken.approve(address(npvSwap), 200e18);
        npvSwap.lockForNPV(alice, alice, 200e18, 1e18, new bytes(0));
        uint256 afterVal = generatorToken.balanceOf(alice);
        assertEq(before - afterVal, 200e18);

        uint256 npvSliced = 653517780000000000;
        assertEq(discounter.discounted(200e18, 1e18), npvSliced);
        assertEq(npvToken.balanceOf(alice), npvSliced);

        ( , uint256 npv, ) = slice.generatedDebt(id1);
        assertEq(npv, 0);

        slice.recordData();

        npvToken.approve(address(slice), npvSliced);
        slice.payDebt(id1, npvSliced);
        slice.unlockDebtSlice(id1);
        assertEq(generatorToken.balanceOf(alice), before);

        vm.expectRevert("YS: already unlocked");
        slice.payDebt(id1, npvSliced);

        vm.expectRevert("YS: no such debt slice");
        slice.payDebt(33333, npvSliced);

        vm.stopPrank();
    }

    function testUnlockWithNPVTokensPayExtra() public {
        init();

        vm.startPrank(alice);

        uint256 id1 = slice.nextId();

        uint256 before = generatorToken.balanceOf(alice);
        generatorToken.approve(address(npvSwap), 200e18);
        npvSwap.lockForNPV(alice, alice, 200e18, 1e18, new bytes(0));
        uint256 afterVal = generatorToken.balanceOf(alice);
        assertEq(before - afterVal, 200e18);

        uint256 npvSliced = 653517780000000000;
        assertEq(discounter.discounted(200e18, 1e18), npvSliced);
        assertEq(npvToken.balanceOf(alice), npvSliced);

        ( , uint256 npv, ) = slice.generatedDebt(id1);
        assertEq(npv, 0);

        slice.recordData();

        generatorToken.approve(address(npvSwap), 200e18);
        npvSwap.lockForNPV(alice, alice, 200e18, 1e18, new bytes(0));

        assertEq(IERC20(npvToken).balanceOf(alice), 2 * npvSliced);
        uint256 extra = npvSliced;

        npvToken.approve(address(slice), npvSliced + extra);
        uint256 npvBefore = npvToken.balanceOf(alice);
        slice.payDebt(id1, npvSliced + extra);
        slice.unlockDebtSlice(id1);
        uint256 npvAfter = npvToken.balanceOf(alice);
        assertEq(generatorToken.balanceOf(alice), before - 200e18);
        assertEq(npvBefore - npvAfter, npvSliced);

        vm.stopPrank();
    }

    function testUnlockWithNPVTokensCreditSlice() public {
        init();

        uint256 id1 = slice.nextId();
        uint256 id2 = slice.nextId() + 1;

        // Alice sells yield
        vm.startPrank(alice);
        uint256 before = generatorToken.balanceOf(alice);
        generatorToken.approve(address(npvSwap), 200e18);
        npvSwap.lockForNPV(alice, alice, 200e18, 1e18, new bytes(0));
        uint256 afterVal = generatorToken.balanceOf(alice);
        assertEq(before - afterVal, 200e18);
        uint256 npvSliced = 653517780000000000;
        assertEq(npvToken.balanceOf(alice), npvSliced);
        npvToken.transfer(bob, npvSliced);
        vm.stopPrank();

        // Bob buys yield
        vm.startPrank(bob);
        npvToken.approve(address(npvSwap), npvSliced);
        npvSwap.swapNPVForSlice(bob, npvSliced, new bytes(0));
        vm.stopPrank();

        assertEq(discounter.discounted(200e18, 1e18), npvSliced);
        ( , uint256 npv1, ) = slice.generatedDebt(id1);
        assertEq(npv1, 0);

        slice.recordData();
        vm.warp(block.timestamp + 100);

        {
            ( , uint256 npv2, ) = slice.generatedDebt(id1);
            assertEq(npv2, 990000000000000);
            ( , uint256 creditNpv2, ) = slice.generatedCredit(id2);
            assertEq(creditNpv2, 989999999999973);

            uint256 remaining = npvSliced - npv2;
            assertEq(remaining, 652527780000000000);

            vm.startPrank(alice);

            // Get some more NPV tokens
            generatorToken.approve(address(npvSwap), 200e18);
            npvSwap.lockForNPV(alice, alice, 200e18, 1e18, new bytes(0));
            assertTrue(npvToken.balanceOf(alice) > remaining);

            npvToken.approve(address(slice), remaining);
            slice.payDebt(id1, remaining);
            slice.unlockDebtSlice(id1);
            vm.stopPrank();
        }

        {
            slice.recordData();
            vm.warp(block.timestamp + discounter.discountPeriod());

            (uint256 creditNominal1, uint256 creditNpv1, uint256 claimable1) = slice.generatedCredit(id2);

            slice.recordData();
            vm.warp(block.timestamp + discounter.discountPeriod());

            (uint256 creditNominal2, uint256 creditNpv2, uint256 claimable2) = slice.generatedCredit(id2);

            assertEq(creditNominal1, creditNominal2);
            assertEq(creditNpv1, creditNpv2);
            assertEq(claimable1, claimable2);
            assertEq(claimable1, 663469827411167512);

            assertEq(creditNpv1, npvSliced);
            assertTrue(creditNominal1 > npvSliced);
            assertEq(creditNominal1, claimable1);
            assertEq(creditNominal1, 663469827411167512);
        }
    }

    function testRefund() public {
        init();

        uint256 id1 = slice.nextId();
        uint256 id2 = slice.nextId() + 1;

        // Alice sells yield
        vm.startPrank(alice);
        generatorToken.approve(address(npvSwap), 200e18);
        npvSwap.lockForNPV(alice, alice, 200e18, 10e18, new bytes(0));
        (, , , , , uint256 npvOwed, ) = slice.debtSlices(id1);
        npvToken.transfer(bob, npvOwed);
        vm.stopPrank();

        // Bob buys yield
        vm.startPrank(bob);
        npvToken.approve(address(npvSwap), npvOwed);
        npvSwap.swapNPVForSlice(bob, npvOwed, new bytes(0));
        (, , , uint256 npvEntitled, , , , ) = slice.creditSlices(id2);
        vm.stopPrank();

        {
            (uint256 nominalDebt1, uint256 npvDebt1, uint256 refund1) = slice.generatedDebt(id1);
            (uint256 nominalCredit1, uint256 npvCredit1, uint256 claimable1) = slice.generatedCredit(id2);
            assertEq(npvOwed, 653517780000000000);
            assertEq(npvEntitled, 653517780000000000);
            assertEq(nominalDebt1, 0);
            assertEq(npvDebt1, 0);
            assertEq(refund1, 0);
            assertEq(nominalCredit1, 0);
            assertEq(npvCredit1, 0);
            assertEq(claimable1, 0);
        }

        vm.warp(block.timestamp + 10);

        {
            (uint256 nominalDebt2, uint256 npvDebt2, uint256 refund2) = slice.generatedDebt(id1);
            (uint256 nominalCredit2, uint256 npvCredit2, uint256 claimable2) = slice.generatedCredit(id2);

            assertEq(npvDebt2, nominalDebt2);
            assertEq(nominalDebt2, 90000000000000);
            assertEq(npvDebt2, 90000000000000);
            assertEq(refund2, 0);

            assertEq(npvCredit2, nominalCredit2);
            assertEq(npvCredit2, claimable2);
            assertEq(npvCredit2, 89999999999997);
            assertEq(nominalCredit2, 89999999999997);
            assertEq(claimable2, 89999999999997);
        }

        vm.warp(block.timestamp + 7 * 7200);

        {
            (uint256 nominalDebt3, uint256 npvDebt3, uint256 refund3) = slice.generatedDebt(id1);
            (uint256 nominalCredit3, uint256 npvCredit3, uint256 claimable3) = slice.generatedCredit(id2);

            assertTrue(npvDebt3 <= nominalDebt3, "debt npv < nominal 3");
            assertEq(nominalDebt3, 504090000000000000);
            assertEq(npvDebt3, 504090000000000000);
            assertEq(refund3, 0);

            assertTrue(npvCredit3 <= nominalCredit3, "credit npv <= nominal 3");
            assertEq(nominalCredit3, 504089999999986564);
            assertEq(npvCredit3, 504089999999986564);
            assertEq(claimable3, 504089999999986564);
        }

        vm.warp(block.timestamp + 7 * 7200);

        {
            (uint256 nominalDebt4, uint256 npvDebt4, uint256 refund4) = slice.generatedDebt(id1);
            (uint256 nominalCredit4, uint256 npvCredit4, uint256 claimable4) = slice.generatedCredit(id2);

            assertEq(nominalDebt4, 653517780000000000);
            assertEq(npvDebt4,     npvOwed);
            assertEq(npvDebt4,     653517780000000000);
            assertEq(refund4,      354572220000000000);

            assertEq(nominalCredit4, 653517780000000000);
            assertEq(npvCredit4,     npvEntitled);
            assertEq(npvCredit4,     653517780000000000);
            assertEq(claimable4,     653517780000000000);

            uint256 aliceBefore = yieldToken.balanceOf(alice);
            vm.prank(alice);
            slice.unlockDebtSlice(id1);
            uint256 aliceAfter = yieldToken.balanceOf(alice);
            assertEq(aliceAfter - aliceBefore, refund4, "refund");

            uint256 bobBefore = yieldToken.balanceOf(bob);
            vm.prank(bob);
            slice.claim(id2, 0);
            uint256 bobAfter = yieldToken.balanceOf(bob);
            assertEq(bobAfter - bobBefore, claimable4, "claimable");
        }
    }

    function testSliceCredit() public  {
        init();

        vm.startPrank(alice);
        uint256 before1 = generatorToken.balanceOf(alice);
        generatorToken.approve(address(npvSwap), 200e18);
        uint256 id1 = npvSwap.lockForNPV(alice, alice, 200e18, 1e18, new bytes(0));
        uint256 afterVal1 = generatorToken.balanceOf(alice);
        assertEq(before1 - afterVal1, 200e18);
        vm.warp(block.timestamp + 0x2000);
        npvToken.transfer(bob, 5e17);
        vm.stopPrank();

        uint256 id2 = slice.nextId();

        vm.startPrank(bob);
        uint256 before2 = yieldToken.balanceOf(bob);
        uint256 delta;
        npvToken.approve(address(npvSwap), 5e17);
        {
            uint256 before = yieldToken.balanceOf(bob);
            npvSwap.swapNPVForSlice(bob, 5e17, new bytes(0));
            slice.claim(id2, 0);
            delta = yieldToken.balanceOf(bob) - before;
        }
        vm.warp(block.timestamp + 0x8000);

        {
            uint256 beforeLimitClaim = yieldToken.balanceOf(bob);
            slice.claim(id2, 100);
            assertEq(yieldToken.balanceOf(bob) - beforeLimitClaim, 100);
        }
        slice.claim(id2, 0);
        uint256 afterVal2 = yieldToken.balanceOf(bob);
        assertEq(afterVal2 - before2, 313365613403807531);
        slice.claim(id2, 0);
        assertEq(afterVal2 - before2, 313365613403807531);

        vm.warp(block.timestamp + 0xf0000);

        uint256 before3 = yieldToken.balanceOf(bob);
        slice.claim(id2, 0);
        uint256 afterVal3 = yieldToken.balanceOf(bob);

        assertEq(afterVal3 - before3 + delta, 249302918736203881);
        assertEq(afterVal3 - before2 + delta, 562668532140011412);

        ( , uint256 npv3, uint256 claimable3) = slice.generatedCredit(id2);
        assertEq(npv3 + delta, 5e17 - 1);
        assertEq(claimable3, 0);

        vm.stopPrank();

        uint256 id3;
        {
            vm.startPrank(alice);
            uint256 remainder = npvToken.balanceOf(alice);
            npvToken.transfer(degen, remainder);
            vm.stopPrank();

            vm.startPrank(degen);
            npvToken.approve(address(npvSwap), remainder);
            id3 = npvSwap.swapNPVForSlice(degen, remainder, new bytes(0));
            assertEq(yieldToken.balanceOf(degen), 0);
            slice.claim(id3, 0);
            assertEq(yieldToken.balanceOf(degen), 153517780000000001);
            vm.stopPrank();
        }

        {
            (uint256 nominal1, , ) = slice.generatedDebt(id1);
            assertEq(nominal1, 653517780000000000);
        }

        {
            (uint256 nominal2, , ) = slice.generatedCredit(id2);
            (uint256 nominal3, , ) = slice.generatedCredit(id3);
            assertClose(nominal2 + nominal3, 653517780000000000, 1e15);
        }
    }

    function testSetUpWithdrawNPV() public returns (uint256, uint256) {
        init();

        vm.startPrank(alice);
        uint256 before1 = generatorToken.balanceOf(alice);
        generatorToken.approve(address(npvSwap), 200e18);
        uint256 id1 = npvSwap.lockForNPV(alice, alice, 200e18, 1e18, new bytes(0));
        uint256 afterVal1 = generatorToken.balanceOf(alice);
        assertEq(before1 - afterVal1, 200e18);
        vm.warp(block.timestamp + 0x2000);
        npvToken.transfer(bob, 5e17);
        vm.stopPrank();

        vm.startPrank(bob);
        npvToken.approve(address(npvSwap), 5e17);
        uint256 id2 = npvSwap.swapNPVForSlice(bob, 5e17, new bytes(0));

        {
            (, , uint256 claimable) = slice.generatedCredit(id2);
            assertEq(claimable, 62668532140011413);
        }

        vm.stopPrank();

        return (id1, id2);
    }

    function testWithdrawNPV() public  {
        (uint256 id1, uint256 id2) = testSetUpWithdrawNPV();

        vm.warp(block.timestamp + 0x8000);

        vm.startPrank(bob);

        uint256 before2 = yieldToken.balanceOf(bob);
        assertEq(before2, 0);
        slice.claim(id2, 0);
        uint256 afterVal2 = yieldToken.balanceOf(bob);
        assertEq(afterVal2 - before2, 313365613403807531);
        assertEq(npvToken.balanceOf(bob), 0);

        slice.withdrawNPV(id2, bob, 1e17);
        assertEq(npvToken.balanceOf(bob), 1e17);
        assertEq(npvToken.balanceOf(address(slice)), 4e17);

        vm.warp(block.timestamp + 0xf0000);

        uint256 claimedId2;
        {
            (uint256 nominal3, uint256 npv3, uint256 claimable3) = slice.generatedCredit(id2);

            assertEq(npv3, creditSliceNPVCredit(id2));
            assertEq(npv3, 86634386596192468);
            assertEq(claimable3, 86634386596192468);
            assertEq(nominal3, 86634386596192468);
            assertEq(npvToken.totalSupply(), 653517780000000000);

            slice.claim(id2, 0);
            uint256 delta = yieldToken.balanceOf(bob);

            assertEq(delta, 399999999999999999);
            assertEq(npvToken.totalSupply(), 253517780000000000);
            claimedId2 = delta;
        }

        vm.warp(block.timestamp + 0xf000);

        {
            ( , , uint256 claimable4) = slice.generatedCredit(id2);
            assertEq(claimable4, 0);
            assertEq(npvToken.totalSupply(), 253517780000000000);
            assertEq(npvToken.balanceOf(bob), 1e17);
            assertEq(npvToken.balanceOf(alice), npvToken.totalSupply() - 1e17);
        }

        npvToken.transfer(chad, 1e17);

        vm.stopPrank();

        vm.startPrank(chad);
        npvToken.approve(address(npvSwap), 1e17);
        uint256 id3 = npvSwap.swapNPVForSlice(chad, 1e17, new bytes(0));
        {
            ( , , uint256 claimable) = slice.generatedCredit(id3);
            (uint256 nominalGen , ,) = slice.generatedDebt(id1);
            assertEq(claimable, 100000000000000000);
            assertEq(nominalGen, 653517780000000000);
        }
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 remainder = npvToken.balanceOf(alice);
        npvToken.transfer(degen, remainder);
        vm.stopPrank();

        vm.startPrank(degen);
        npvToken.approve(address(npvSwap), remainder);
        uint256 id4 = npvSwap.swapNPVForSlice(degen, remainder, new bytes(0));

        {
            ( , , uint256 claimable3) = slice.generatedCredit(id3);
            ( , , uint256 claimable4) = slice.generatedCredit(id4);
            (uint256 nominalGen , ,) = slice.generatedDebt(id1);
            assertEq(claimable4, 153517780000000001);
            assertEq(nominalGen, 653517780000000000);
            assertEq(claimedId2 + claimable3 + claimable4, 653517780000000000);
            assertClose(claimedId2 + claimable3 + claimable4,
                        nominalGen,
                        nominalGen / 100);
        }
        vm.stopPrank();
    }

    function testWithdrawNPVFullAmount() public  {
        (, uint256 id2) = testSetUpWithdrawNPV();

        vm.warp(block.timestamp + 0x8000);

        vm.startPrank(bob);

        slice.claim(id2, 0);

        assertEq(npvToken.balanceOf(bob), 0);

        vm.expectRevert("YS: insufficient NPV");
        slice.withdrawNPV(id2, bob, 100e17);

        slice.withdrawNPV(id2, bob, 0);
        assertEq(npvToken.balanceOf(bob), 186634386596192468);

        vm.stopPrank();
    }

    function testWithdrawNPVZero() public  {
        init();

        vm.startPrank(alice);
        generatorToken.approve(address(npvSwap), 200e18);
        npvSwap.lockForNPV(alice, alice, 200e18, 1e18, new bytes(0));
        npvToken.transfer(bob, 5e17);
        vm.stopPrank();

        vm.startPrank(bob);
        npvToken.approve(address(npvSwap), 5e17);
        uint256 id2 = npvSwap.swapNPVForSlice(bob, 0, new bytes(0));
        slice.withdrawNPV(id2, bob, 0);
        vm.stopPrank();
    }

    function testWithdrawNPVRequire() public {
        init();

        vm.startPrank(alice);
        generatorToken.approve(address(npvSwap), 20000e18);
        npvSwap.lockForNPV(alice, alice, 20000e18, 100e18, new bytes(0));
        npvToken.transfer(bob, 50e18);
        vm.stopPrank();

        vm.startPrank(bob);
        npvToken.approve(address(npvSwap), 50e18);
        npvSwap.swapNPVForSlice(bob, 50e18, new bytes(0));
        vm.stopPrank();

        vm.expectRevert("YS: no such credit slice");
        slice.withdrawableNPV(999);
    }

    function testWithdrawNPVAccountsWithdrawableImmediate() public {
        init();

        vm.startPrank(alice);
        generatorToken.approve(address(npvSwap), 20000e18);
        npvSwap.lockForNPV(alice, alice, 20000e18, 100e18, new bytes(0));
        npvToken.transfer(bob, 50e18);
        vm.stopPrank();

        vm.startPrank(bob);
        npvToken.approve(address(npvSwap), 50e18);
        uint256 id2 = npvSwap.swapNPVForSlice(bob, 50e18, new bytes(0));
        assertEq(slice.withdrawableNPV(id2), 50e18);
        vm.stopPrank();
    }

    function testTimeShiftAccounting() public  {
        init();

        vm.startPrank(alice);
        generatorToken.approve(address(npvSwap), 20000e18);
        npvSwap.lockForNPV(alice, alice, 20000e18, 100e18, new bytes(0));
        npvToken.transfer(bob, 50e18);
        vm.stopPrank();

        // Obtain a credit slice
        vm.startPrank(bob);
        npvToken.approve(address(npvSwap), 50e18);
        uint256 id2 = npvSwap.swapNPVForSlice(bob, 50e18, new bytes(0));

        // Move forward in time and receive dust NPV, triggering call to shiftForward
        vm.warp(block.timestamp + 0xf0000);

        ( , uint256 npvGenBefore, ) = slice.generatedCredit(id2);

        // Receive 1 unit of NPV tokens, verify accounting.
        slice.withdrawNPV(id2, bob, 1);
        {
            uint256 npvCreditAfter = creditSliceNPVCredit(id2);

            ( , uint256 tsCreated, uint256 ts, , , , , ) = slice.creditSlices(id2);
            uint256 npvCreditAfterShifted = slice.discounter().shiftBackward(ts - tsCreated, npvCreditAfter);

            assertEq(creditSliceNPVTokens(id2), 50e18 - 1);
            assertEq(npvCreditAfterShifted + npvGenBefore, 50e18 - 1);

            // The withdrawable NPV tokens should be equal to the the total NPV tokens locked,
            // minus what was withdrawn, minus the NPV generated relative to the creation time.
            assertEq(slice.withdrawableNPV(id2) + npvGenBefore, 50e18 - 1);
        }

        // Withdraw 100 units of NPV tokens, verify accounting
        slice.withdrawNPV(id2, bob, 100);
        assertEq(slice.withdrawableNPV(id2) + npvGenBefore, 50e18 - 101);
        assertEq(npvToken.balanceOf(bob), 101);

        // Move forward in time a little, do more NPV token withdrawals, verify accounting
        vm.warp(block.timestamp + 10);

        uint256 npvGen2;
        {
            ( , uint256 npvGen, ) = slice.generatedCredit(id2);
            ( , uint256 tsCreated, uint256 ts, , , , , ) = slice.creditSlices(id2);
            npvGen2 = slice.discounter().shiftBackward(ts - tsCreated, npvGen);
        }

        // Withdraw 2 units of NPV tokens, verify accounting
        slice.withdrawNPV(id2, bob, 2);
        assertEq(slice.withdrawableNPV(id2) + npvGenBefore + npvGen2, 50e18 - 103);
        assertEq(npvToken.balanceOf(bob), 103);

        // Withdraw 200 units of NPV tokens, verify accounting
        slice.withdrawNPV(id2, bob, 200);
        assertEq(slice.withdrawableNPV(id2) + npvGenBefore + npvGen2, 50e18 - 303);
        assertEq(npvToken.balanceOf(bob), 303);

        // Withdraw 1e18 units of NPV tokens, verify accounting, transfer to Chad
        slice.withdrawNPV(id2, bob, 1e18);
        assertEq(slice.withdrawableNPV(id2) + npvGenBefore + npvGen2, 50e18 - 303 - 1e18);
        assertEq(npvToken.balanceOf(bob), 1e18 + 303);

        npvToken.transfer(chad, 1e18);
        assertEq(npvToken.balanceOf(bob), 303);
        assertEq(npvToken.balanceOf(chad), 1e18);

        vm.stopPrank();

        // Chad sends some of his NPV tokens to Degen, locks rest into a slice
        vm.startPrank(chad);
        npvToken.transfer(degen, 2e17);
        assertEq(npvToken.balanceOf(chad), 8e17);
        assertEq(npvToken.balanceOf(degen), 2e17);

        npvToken.approve(address(slice), 8e17);
        uint256 id3 = slice.creditSlice(8e17, chad, "");

        // Withdrawable NPV will be less than what we just locked, because some yield
        // has already vested from the unallocated slice
        assertTrue(slice.withdrawableNPV(id3) < 8e17);

        vm.stopPrank();

        // Move forward in time so that all yield is vested

        vm.warp(block.timestamp + 0xf00000);

        vm.startPrank(degen);
        npvToken.approve(address(slice), 2e17);
        uint256 id4 = slice.creditSlice(2e17, degen, "");
        vm.stopPrank();

        // Since all the yield is vested, no NPV tokens are withdrawable
        assertEq(slice.withdrawableNPV(id2), 0);
        assertEq(slice.withdrawableNPV(id3), 0);
        assertEq(slice.withdrawableNPV(id4), 0);

        vm.prank(bob);
        uint256 claimed1 = slice.claim(id2, 0);

        vm.prank(chad);
        uint256 claimed2 = slice.claim(id3, 0);

        vm.prank(degen);
        uint256 claimed3 = slice.claim(id4, 0);

        // Total nominal amount should be greater than the discounted (NPV) amount
        assertTrue(claimed1 + claimed2 + claimed3 > 50e18);
        assertEq(claimed1 + claimed2 + claimed3, 51053218269215920265);
    }

    function testComputePVAndNominal() public {
        init();

        uint256 pv = discounter.shiftBackward(360 days, 1e17);
        assertEq(pv, 83413196834087708);

        uint256 nominal = discounter.shiftForward(360 days, pv);
        assertEq(nominal, 99999999999999999);
        assertClose(nominal, 1e17, 10);
    }

    function testFees() public {
        init();

        slice.setTreasury(treasury);
        slice.setDebtFee(5_0);
        slice.setCreditFee(10_0);

        vm.startPrank(alice);
        uint256 before = generatorToken.balanceOf(alice);
        generatorToken.approve(address(npvSwap), 200e18);
        npvSwap.lockForNPV(alice, alice, 200e18, 1e18, new bytes(0));
        uint256 afterVal = generatorToken.balanceOf(alice);
        assertEq(before - afterVal, 200e18);
        uint256 npv = discounter.discounted(200e18, 1e18);
        assertEq(npv, 653517780000000000);
        uint256 expectedDebtFee = ((1e18 - npv) * 5_0) / 100_0;
        assertEq(npvToken.balanceOf(alice), npv - expectedDebtFee);
        assertEq(npvToken.balanceOf(treasury), expectedDebtFee);
        npvToken.transfer(bob, 5e17);
        vm.stopPrank();

        uint256 id2 = slice.nextId();

        vm.startPrank(bob);
        npvToken.approve(address(npvSwap), 5e17);
        npvSwap.swapNPVForSlice(bob, 5e17, new bytes(0));

        vm.warp(block.timestamp + 0x8000);

        uint256 before2 = yieldToken.balanceOf(bob);
        slice.claim(id2, 0);
        uint256 afterVal2 = yieldToken.balanceOf(bob);
        uint256 total2 = 250697081263796118;
        assertEq(afterVal2 - before2, total2 - (total2 * 10_0) / (100_0) - 1);

        vm.warp(block.timestamp + 0xf000);

        uint256 before3 = yieldToken.balanceOf(bob);
        slice.claim(id2, 0);
        uint256 afterVal3 = yieldToken.balanceOf(bob);

        uint256 total3 = 249302918736203882;
        uint256 total4 = 500000000000000000;

        assertEq(afterVal3 - before3, total3 - (total3 * 10_0) / (100_0));
        assertEq(afterVal3 - before2, total4 - (total4 * 10_0) / (100_0));

        ( , uint256 npv3, uint256 claimable3) = slice.generatedCredit(id2);
        assertEq(npv3, 45e16);
        assertEq(claimable3, 0);

        vm.stopPrank();

        assertEq(npvToken.balanceOf(treasury), expectedDebtFee + 5e16);
    }

    function testUnlockAmounts() public {
        init();

        // Alice sells yield
        vm.startPrank(alice);
        generatorToken.approve(address(npvSwap), 200e18);
        uint256 beforeAlice = generatorToken.balanceOf(alice);
        uint256 idAlice = npvSwap.lockForNPV(alice, alice, 200e18, 1e18, new bytes(0));
        uint256 deltaAlice = beforeAlice - generatorToken.balanceOf(alice);
        assertEq(deltaAlice, 200e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1000);

        // Bob sells yield
        source.mintGenerator(bob, 200e18);

        vm.startPrank(bob);
        generatorToken.approve(address(npvSwap), 100e18);
        uint256 beforeBob = generatorToken.balanceOf(bob);
        uint256 idBob = npvSwap.lockForNPV(bob, bob, 100e18, 1e18, new bytes(0));
        uint256 deltaBob = beforeBob - generatorToken.balanceOf(bob);
        assertEq(deltaBob, 100e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 0xf0000);

        vm.startPrank(alice);
        slice.unlockDebtSlice(idAlice);
        vm.stopPrank();

        vm.startPrank(bob);
        slice.unlockDebtSlice(idBob);
        vm.stopPrank();

        assertEq(generatorToken.balanceOf(alice), beforeAlice);
        assertEq(generatorToken.balanceOf(alice), 1000000e18);

        assertEq(generatorToken.balanceOf(bob), beforeBob);
        assertEq(generatorToken.balanceOf(bob), 200e18);
    }

    function testSetGov() public {
        init();

        slice.setGov(alice);

        vm.expectRevert("YS: only gov");
        slice.setGov(bob);

        vm.prank(alice);
        slice.setGov(bob);
    }

    function testSetTreasury() public {
        init();

        vm.startPrank(alice);
        vm.expectRevert("YS: only gov");
        slice.setTreasury(bob);
        vm.stopPrank();

        slice.setTreasury(bob);
    }

    function testSetDustLimit() public {
        init();

        vm.startPrank(alice);
        vm.expectRevert("YS: only gov");
        slice.setDustLimit(10);
        vm.stopPrank();

        vm.startPrank(alice);
        generatorToken.approve(address(npvSwap), 200e18);
        vm.expectRevert("YS: dust");
        npvSwap.lockForNPV(alice, alice, 10, 1e18, new bytes(0));
        vm.expectRevert("YS: dust");
        npvSwap.lockForNPV(alice, alice, 11, 1e18, new bytes(0));
        vm.stopPrank();

        slice.setDustLimit(10);

        vm.startPrank(alice);
        generatorToken.approve(address(npvSwap), 200e18);
        vm.expectRevert("YS: dust");
        npvSwap.lockForNPV(alice, alice, 10, 1e18, new bytes(0));
        npvSwap.lockForNPV(alice, alice, 11, 1e18, new bytes(0));
        vm.stopPrank();
    }

    function testSetDebtFee() public {
        init();

        vm.startPrank(alice);
        vm.expectRevert("YS: only gov");
        slice.setDebtFee(1);
        vm.stopPrank();

        vm.expectRevert("YS: max debt fee");
        slice.setDebtFee(100_1);

        slice.setDebtFee(100_0);
    }

    function testSetCreditFee() public {
        init();

        vm.startPrank(alice);
        vm.expectRevert("YS: only gov");
        slice.setCreditFee(1);
        vm.stopPrank();

        vm.expectRevert("YS: max credit fee");
        slice.setCreditFee(20_1);

        slice.setCreditFee(20_0);
    }

    function testDebtSliceSmallValues() public {
        testFuzz_debtSlice(1e9);
        testFuzz_debtSlice(2e9);
        testFuzz_debtSlice(3e9);
    }
    function testDebtSliceRegularValues() public {
        testFuzz_debtSlice(1e18);
        testFuzz_debtSlice(2e18);
        testFuzz_debtSlice(10e18);
        testFuzz_debtSlice(100e18);
    }

    function testDebtSliceLargeValues() public {
        testFuzz_debtSlice(1e27 - 1);
        testFuzz_debtSlice(1e26);
    }

    function testFuzz_debtSlice(uint256 amountYield) public {
        if (!vm.envOr("RUN_FUZZ", false)) return;

        vm.assume(amountYield >= 1e9);
        vm.assume(amountYield <= 1e27);

        uint256 amountGenerator = 200e18;
        uint256 yps = amountYield / 1000 + 1;
        amountYield = amountYield / 10;

        init(yps);

        vm.startPrank(alice);
        uint256 before = generatorToken.balanceOf(alice);
        generatorToken.approve(address(slice), amountGenerator);
        uint256 id1 = slice.debtSlice(alice, alice, amountGenerator, amountYield, "");
        assertEq(generatorToken.balanceOf(alice), before - amountGenerator);
        uint256 npvSliced = npvToken.balanceOf(alice);
        npvToken.transfer(bob, npvToken.balanceOf(alice));
        vm.stopPrank();

        vm.warp(block.timestamp + 10);

        vm.startPrank(bob);
        npvToken.approve(address(slice), npvSliced);
        uint256 id2 = slice.creditSlice(npvSliced, bob, "");
        vm.stopPrank();

        vm.warp(block.timestamp + amountYield / yps + 10);

        vm.startPrank(alice);
        slice.unlockDebtSlice(id1);
        assertEq(generatorToken.balanceOf(alice), before);
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 claimed = slice.claim(id2, 0);
        assertTrue(yieldToken.balanceOf(bob) >= npvSliced);
        assertTrue(yieldToken.balanceOf(bob) <= amountYield);
        assertEq(yieldToken.balanceOf(bob), claimed);
        vm.stopPrank();
    }

    function testTransferRegularValues() public {
        testFuzz_transfers(1e18);
        testFuzz_transfers(2e18);
        testFuzz_transfers(10e18);
        testFuzz_transfers(100e18);
        testFuzz_transfers(3955221184997775880);
    }

    function testTransferLargeValues() public {
        testFuzz_transfers(1e27 - 1);
        testFuzz_transfers(1e26);
    }

    function testFuzz_transfers(uint256 amountYield) public {
        if (!vm.envOr("RUN_FUZZ", false)) return;

        vm.assume(amountYield >= 1e18);
        vm.assume(amountYield <= 1e27);

        amountYield = amountYield / 10;
        uint256 amountGenerator = 200e18;
        uint256 numPeriods = 360;

        {
            uint256 yieldPerPeriod = amountYield / numPeriods;
            uint256 yps = yieldPerPeriod / 1 days;
            init(yps);
            slice.discounter().setDaily(yps * 1 days);
        }

        uint256 sum;
        {
            vm.startPrank(alice);
            uint256 before = generatorToken.balanceOf(alice);
            generatorToken.approve(address(slice), amountGenerator);
            uint256 id1 = slice.debtSlice(alice, alice, amountGenerator, amountYield, "");
            assertEq(generatorToken.balanceOf(alice), before - amountGenerator);
            uint256 npvSliced = npvToken.balanceOf(alice);
            npvToken.transfer(bob, npvToken.balanceOf(alice));
            vm.stopPrank();

            vm.startPrank(bob);
            npvToken.approve(address(slice), npvSliced);
            uint256 id2 = slice.creditSlice(npvSliced, bob, "");
            vm.stopPrank();

            vm.warp(block.timestamp + slice.discounter().discountPeriod() + 10);

            uint256 beforeTransfer = yieldToken.balanceOf(bob);
            vm.startPrank(bob);
            slice.withdrawNPV(id2, bob, npvSliced / 2);
            slice.transferOwnership(id2, chad);
            uint256 claimTransfer = yieldToken.balanceOf(bob) - beforeTransfer;
            vm.stopPrank();

            vm.warp(block.timestamp + (numPeriods / 2) * slice.discounter().discountPeriod() + 10);

            vm.startPrank(bob);
            npvToken.transfer(degen, npvSliced / 4);
            npvToken.approve(address(slice), npvSliced / 4);
            uint256 id3 = slice.creditSlice(npvSliced / 4, bob, "");
            vm.stopPrank();

            vm.startPrank(degen);
            npvToken.approve(address(slice), npvSliced / 4);
            uint256 id4 = slice.creditSlice(npvSliced / 4, degen, "");
            vm.stopPrank();

            vm.warp(block.timestamp + (10 * numPeriods) * slice.discounter().discountPeriod());

            vm.startPrank(alice);
            slice.unlockDebtSlice(id1);
            assertEq(generatorToken.balanceOf(alice), before);
            vm.stopPrank();

            sum = claimTransfer;
            vm.prank(chad);
            sum += slice.claim(id2, 0);

            vm.prank(bob);
            sum += slice.claim(id3, 0);

            vm.prank(degen);
            sum += slice.claim(id4, 0);


            assertTrue(sum > npvSliced);
            assertTrue(sum > amountYield, "discount applied");
            assertTrue(sum <= amountYield * 2, "sanity check");
        }

        // Do the same thing, but without transfers, and verify that total yield paid out is the same
        {
            vm.startPrank(alice);
            uint256 before = generatorToken.balanceOf(alice);
            generatorToken.approve(address(slice), amountGenerator);
            uint256 id1 = slice.debtSlice(alice, alice, amountGenerator, amountYield, "");
            assertEq(generatorToken.balanceOf(alice), before - amountGenerator);
            uint256 npvSliced = npvToken.balanceOf(alice);
            npvToken.transfer(bob, npvToken.balanceOf(alice));
            vm.stopPrank();

            vm.startPrank(bob);
            npvToken.approve(address(slice), npvSliced);
            uint256 id2 = slice.creditSlice(npvSliced, bob, "");
            vm.stopPrank();

            vm.warp(block.timestamp + 10 * numPeriods * slice.discounter().discountPeriod());

            vm.startPrank(alice);
            slice.unlockDebtSlice(id1);
            assertEq(generatorToken.balanceOf(alice), before);
            vm.stopPrank();

            vm.prank(bob);
            uint256 claimed = slice.claim(id2, 0);

            assertClose(sum, claimed, sum / 1e6);
        }
    }

    function testRolloverSetup() public returns (uint256) {
        init(10000000000);
        discounter.setMaxDays(1440);

        vm.startPrank(alice);

        uint256 id1 = slice.nextId();

        uint256 before = generatorToken.balanceOf(alice);
        generatorToken.approve(address(npvSwap), 200e18);
        npvSwap.lockForNPV(alice, alice, 200e18, 1e18, new bytes(0));
        uint256 afterVal = generatorToken.balanceOf(alice);
        assertEq(before - afterVal, 200e18);

        assertEq(discounter.discounted(200e18, 1e18), 877248880000000000);
        assertEq(npvToken.balanceOf(alice), 877248880000000000);
        assertEq(debtSliceNPVDebt(id1), 877248880000000000);

        vm.expectRevert("YS: npv debt");
        slice.unlockDebtSlice(id1);

        for (uint256 day = 0; day < 100; day += 7) {
            vm.warp(block.timestamp + 7 days);
            slice.recordData();
        }
        vm.expectRevert("YS: npv debt");
        slice.unlockDebtSlice(id1);

        for (uint256 day = 0; day < 100; day += 7) {
            vm.warp(block.timestamp + 7 days);
            slice.recordData();
        }
        vm.expectRevert("YS: npv debt");
        slice.unlockDebtSlice(id1);

        (uint256 remainingNPV1,
         uint256 incrementalNPV1,
         ) = slice.previewRollover(id1, 1e18);

        for (uint256 day = 0; day < 100; day += 7) {
            vm.warp(block.timestamp + 7 days);
            slice.recordData();
        }

        (uint256 remainingNPV2,
         uint256 incrementalNPV2,
         ) = slice.previewRollover(id1, 1e18);

        assertTrue(remainingNPV2 < remainingNPV1);
        assertTrue(incrementalNPV2 > incrementalNPV1);

        vm.stopPrank();

        return id1;
    }

    function testRolloverApproval() public {
        uint256 id1 = testRolloverSetup();

        vm.warp(block.timestamp + 200 days);

        vm.expectRevert("YS: only owner or approved");
        slice.rollover(id1, alice, 1e18);

        vm.expectRevert("YS: only owner");
        slice.approveRollover(id1, bob, 1e18);

        vm.startPrank(alice);
        slice.approveRollover(id1, bob, 1e18);
        vm.stopPrank();

        vm.startPrank(bob);
        // Verify only exact amount works
        vm.expectRevert("YS: only owner or approved");
        slice.rollover(id1, alice, 500);
        vm.expectRevert("YS: only owner or approved");
        slice.rollover(id1, alice, 1e18 - 1);
        vm.expectRevert("YS: only owner or approved");
        slice.rollover(id1, alice, 1e18 + 1);

        slice.rollover(id1, alice, 1e18);

        // Verify it only works once
        vm.expectRevert("YS: only owner or approved");
        slice.rollover(id1, alice, 1e18);

        vm.stopPrank();
    }

    function testRolloverAtEnd() public {
        uint256 id1 = testRolloverSetup();

        vm.warp(block.timestamp + 1440 days);

        // Rollover after all NPV debt is paid should be same value as minting a new slice
        (uint256 npv, ) = slice.previewDebtSlice(200e18, 1e18);
        (uint256 remainingNPV,
         uint256 incrementalNPV,
         ) = slice.previewRollover(id1, 1e18);
        assertEq(npv, 877248880000000000);
        assertEq(remainingNPV, 0);
        assertEq(incrementalNPV, 0);

        vm.startPrank(alice);

        vm.expectRevert("YS: cannot rollover");
        slice.rollover(id1, alice, 1e18);

        vm.stopPrank();
    }

    function testRolloverRateChanges() public {
        uint256 id1 = testRolloverSetup();

        discounter.setDaily(1);
        
        vm.startPrank(alice);

        vm.expectRevert("YS: cannot rollover");
        slice.rollover(id1, alice, 1e18);

        vm.stopPrank();
    }

    function testRolloverSuccess() public {
        uint256 id1 = testRolloverSetup();

        vm.warp(block.timestamp + 200 days);

        // All the debt isn't paid, so the rollover should be smaller than a new slice
        (uint256 npv, ) = slice.previewDebtSlice(200e18, 1e18);
        (uint256 remainingNPV,
         uint256 incrementalNPV,
         ) = slice.previewRollover(id1, 1e18);
        assertTrue(remainingNPV < npv);
        assertTrue(remainingNPV < 877248880000000000);
        assertTrue(incrementalNPV < npv);
        assertTrue(incrementalNPV < 877248880000000000);

        vm.expectRevert("YS: only owner or approved");
        slice.rollover(id1, alice, 1e18);

        // Roll it over!
        vm.startPrank(alice);

        uint256 debtBefore = slice.remaining(id1);
        uint256 balanceBefore = npvToken.balanceOf(alice);
        debtBefore = discounter.shiftForward(515 days, debtBefore);

        slice.rollover(id1, alice, 1e18);

        uint256 debtAfter = slice.remaining(id1);
        uint256 balanceAfter = npvToken.balanceOf(alice);

        assertEq(debtAfter - debtBefore, incrementalNPV);
        assertEq(balanceAfter - balanceBefore, incrementalNPV);

        vm.warp(block.timestamp + 925 days);

        // This would have succeeded without the rollover
        vm.expectRevert("YS: npv debt");
        slice.unlockDebtSlice(id1);

        vm.warp(block.timestamp + 1000 days);

        uint256 generatorBefore = generatorToken.balanceOf(address(alice));
        slice.unlockDebtSlice(id1);
        assertEq(generatorToken.balanceOf(address(alice)) - generatorBefore, 200e18);

        (, , uint256 claimable) = slice.generatedCredit(slice.UNALLOC_ID());
        assertTrue(claimable > 2 * npv);
        assertEq(claimable, 1844134318548995502);

        vm.stopPrank();
    }

    function setUpRefundsAccounting() public returns (uint256, uint256, uint256, uint256, uint256) {
        init();

        // First debt slice: many tokens, 100 yield
        vm.startPrank(alice);
        generatorToken.approve(address(slice), 200e18);
        uint256 id1 = slice.debtSlice(alice, alice, 200e18, 100, "");
        vm.stopPrank();

        vm.warp(block.timestamp + 0x10);

        // Second debt slice: many tokens, 100 yield
        vm.startPrank(alice);
        generatorToken.approve(address(slice), 200e18);
        uint256 id2 = slice.debtSlice(alice, alice, 200e18, 100, "");
        vm.stopPrank();

        vm.warp(block.timestamp + 0x10);

        // Third debt slice: many tokens, 1e18 yield
        source.mintBoth(chad, 1000e18);
        vm.startPrank(chad);
        generatorToken.approve(address(slice), 200e18);
        uint256 id3 = slice.debtSlice(chad, chad, 200e18, 1e18, "");
        vm.stopPrank();

        vm.warp(block.timestamp + 0x10);

        // Transfer all NPV tokens to bob
        vm.startPrank(alice);
        npvToken.transfer(bob, npvToken.balanceOf(alice));
        vm.stopPrank();

        vm.startPrank(chad);
        npvToken.transfer(bob, npvToken.balanceOf(chad));
        vm.stopPrank();


        uint256 all = npvToken.balanceOf(bob);
        uint256 half = all / 2;

        vm.startPrank(bob);
        npvToken.approve(address(slice), all);
        uint256 id4 = slice.creditSlice(half, bob, "");
        uint256 id5 = slice.creditSlice(half, bob, "");
        vm.stopPrank();

        return (id1, id2, id3, id4, id5);
    }

    function testRefundsAccountingShort() public {
        (uint256 id1,
         uint256 id2,
         uint256 id3,
         uint256 id4,
         uint256 id5
         ) = setUpRefundsAccounting();

        // Move ahead a short amount of time. This means id1 and id2 will have
        // large refunds (since they only locked a small amount of yield, but
        // id3 will have a small refund (since it just barely paid off its debt)
        vm.warp(block.timestamp + 2 days + 12 hours);

        uint256 sumYieldAmounts;
        {
            (uint256 nominal1, , uint256 refund1) = slice.generatedDebt(id1);
            (uint256 nominal2, , uint256 refund2) = slice.generatedDebt(id2);
            (uint256 nominal3, , uint256 refund3) = slice.generatedDebt(id3);

            (uint256 creditNominal1, , uint256 claimable1) = slice.generatedCredit(id4);
            (uint256 creditNominal2, , uint256 claimable2) = slice.generatedCredit(id5);

            sumYieldAmounts = (refund1 +
                               refund2 +
                               refund3 +
                               claimable1 +
                               claimable2);

            assertTrue(nominal1 * 1e9 < nominal3, "relative values sanity check");
            assertTrue(nominal2 * 1e9 < nominal3, "relative values sanity check");
            assertTrue(refund1 > refund3 * 10, "relative refund sanity check");
            assertTrue(refund2 > refund3 * 10, "relative refund sanity check");

            assertEq(nominal1, 98);
            assertEq(nominal2, 98);
            assertEq(nominal3, 653517780000000000);
            assertEq(claimable1, claimable2);
            assertEq(claimable1, 326758890000000098);
            assertEq(claimable2, 326758890000000098);
            assertEq(creditNominal1, creditNominal2);
            assertEq(creditNominal1, 326758890000000098);
            assertEq(creditNominal2, 326758890000000098);
            assertEq(creditNominal1 + creditNominal2,
                     nominal1 + nominal2 + nominal3);
        }

        slice.harvest();

        {
            assertClose(sumYieldAmounts,
                        yieldToken.balanceOf(address(slice)),
                        sumYieldAmounts / 1000);
        }

        {
            uint256 aliceBefore = yieldToken.balanceOf(alice);
            uint256 bobBefore = yieldToken.balanceOf(bob);
            uint256 chadBefore = yieldToken.balanceOf(chad);

            vm.startPrank(alice);
            slice.unlockDebtSlice(id1);
            slice.unlockDebtSlice(id2);
            vm.stopPrank();

            vm.startPrank(chad);
            slice.unlockDebtSlice(id3);
            vm.stopPrank();

            vm.startPrank(bob);
            slice.claim(id4, 0);
            slice.claim(id5, 0);
            vm.stopPrank();

            uint256 deltaAlice = yieldToken.balanceOf(alice) - aliceBefore;
            uint256 deltaBob = yieldToken.balanceOf(bob) - bobBefore;
            uint256 deltaChad = yieldToken.balanceOf(chad) - chadBefore;

            assertTrue(deltaAlice > deltaChad * 10, "relative refund sanity check");
            assertClose(deltaAlice + deltaBob + deltaChad, sumYieldAmounts, sumYieldAmounts / 1000);
        }
    }

    function testRefundsAccountingLong() public {
        (uint256 id1,
         uint256 id2,
         uint256 id3,
         uint256 id4,
         uint256 id5
         ) = setUpRefundsAccounting();

        // In this test we move ahead many days. This will result in large refunds
        // for all three debt slices.
        vm.warp(block.timestamp + 2000 days);

        uint256 sumYieldAmounts;
        {
            (uint256 nominal1, , uint256 refund1) = slice.generatedDebt(id1);
            (uint256 nominal2, , uint256 refund2) = slice.generatedDebt(id2);
            (uint256 nominal3, , uint256 refund3) = slice.generatedDebt(id3);

            (uint256 creditNominal1, , uint256 claimable1) = slice.generatedCredit(id4);
            (uint256 creditNominal2, , uint256 claimable2) = slice.generatedCredit(id5);

            sumYieldAmounts = (refund1 +
                               refund2 +
                               refund3 +
                               claimable1 +
                               claimable2);

            assertTrue(nominal1 * 1e9 < nominal3, "relative values sanity check");
            assertTrue(nominal2 * 1e9 < nominal3, "relative values sanity check");

            // With long waiting period without unlock, refund is socialized
            // across all debt slices
            assertClose(refund1, refund3, refund3 / 10);
            assertClose(refund2, refund3, refund3 / 10);

            assertEq(nominal1, 99);
            assertEq(nominal2, 99);
            assertEq(nominal3, 663469827411167512);
            assertEq(claimable1, claimable2);
            assertEq(claimable1, 331733771573604158);
            assertEq(claimable2, 331733771573604158);
            assertEq(creditNominal1, creditNominal2);
            assertEq(creditNominal1, 331733771573604158);
            assertEq(creditNominal2, 331733771573604158);
            assertClose(creditNominal1 + creditNominal2,
                        nominal1 + nominal2 + nominal3,
                        creditNominal1 / 1000);
        }

        slice.harvest();

        {
            assertClose(sumYieldAmounts,
                        yieldToken.balanceOf(address(slice)),
                        sumYieldAmounts / 1000);
        }

        {
            uint256 aliceBefore = yieldToken.balanceOf(alice);
            uint256 bobBefore = yieldToken.balanceOf(bob);
            uint256 chadBefore = yieldToken.balanceOf(chad);

            vm.startPrank(alice);
            slice.unlockDebtSlice(id1);
            slice.unlockDebtSlice(id2);
            vm.stopPrank();

            vm.startPrank(chad);
            slice.unlockDebtSlice(id3);
            vm.stopPrank();

            vm.startPrank(bob);
            slice.claim(id4, 0);
            slice.claim(id5, 0);
            vm.stopPrank();

            uint256 deltaAlice = yieldToken.balanceOf(alice) - aliceBefore;
            uint256 deltaBob = yieldToken.balanceOf(bob) - bobBefore;
            uint256 deltaChad = yieldToken.balanceOf(chad) - chadBefore;

            assertClose(deltaAlice, 2 * deltaChad, deltaChad / 10);
            assertClose(deltaAlice + deltaBob + deltaChad, sumYieldAmounts, sumYieldAmounts / 1000);
        }
    }

    function testMintFromYield() public {
        init();

        vm.startPrank(alice);

        yieldToken.approve(address(slice), 1e18);

        uint256 balanceBefore = slice.npvToken().balanceOf(alice);
        uint256 activeBefore = slice.activeNPV();
        uint256 cumYieldBefore = slice.cumulativePaidYield();

        slice.mintFromYield(address(alice), 1e18);

        uint256 balanceDelta = slice.npvToken().balanceOf(alice) - balanceBefore;
        uint256 activeDelta = slice.activeNPV() - activeBefore;
        uint256 cumYieldDelta = slice.cumulativePaidYield() - cumYieldBefore;

        assertEq(balanceDelta, 1e18);
        assertEq(activeDelta, 1e18);
        assertEq(cumYieldDelta, 1e18);

        vm.expectRevert("YS: zero address");
        slice.mintFromYield(address(0), 1e18);

        vm.expectRevert("YS: this address");
        slice.mintFromYield(address(slice), 1e18);

        vm.stopPrank();
    }

    function testZeroYieldDoubleLock() public {
        init(0);
        discounter.setMaxDays(1440);

        vm.startPrank(alice);

        uint256 id1 = slice.nextId();

        uint256 before = generatorToken.balanceOf(alice);
        generatorToken.approve(address(npvSwap), 200e18);
        npvSwap.lockForNPV(alice, alice, 10e18, 1e18, new bytes(0));
        npvSwap.lockForNPV(alice, alice, 10e18, 1e18, new bytes(0));
        uint256 afterVal = generatorToken.balanceOf(alice);
        assertEq(before - afterVal, 20e18);
    }
}
