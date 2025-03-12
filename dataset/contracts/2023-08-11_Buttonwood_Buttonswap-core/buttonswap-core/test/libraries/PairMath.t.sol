// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import {Test} from "buttonswap-core_forge-std/Test.sol";
import {PairMath} from "../../src/libraries/PairMath.sol";
import {Math} from "../../src/libraries/Math.sol";

contract PairMathTest is Test {
    function test_getDualSidedMintLiquidityOutAmount_usingReservoirA(
        uint256 totalLiquidity,
        uint256 amountInA,
        uint256 amountInB,
        uint256 poolA,
        uint256 poolB,
        uint256 reservoirA
    ) public {
        // Pools will be capped by uint112
        vm.assume(poolA < type(uint112).max);
        vm.assume(poolB < type(uint112).max);

        // Function reverts with div by zero if either of these are zero
        vm.assume(poolA > 0 && poolB > 0);

        // Ensuring we don't overflow
        if (amountInA > 0) {
            vm.assume(totalLiquidity < (type(uint256).max / amountInA));
        }
        if (amountInB > 0) {
            vm.assume(totalLiquidity < (type(uint256).max / amountInB));
        }
        vm.assume(reservoirA < (type(uint256).max - poolA));

        uint256 liquidityOut =
            PairMath.getDualSidedMintLiquidityOutAmount(totalLiquidity, amountInA, amountInB, poolA + reservoirA, poolB);
        uint256 expectedLiquidityOut =
            Math.min((totalLiquidity * amountInA) / (poolA + reservoirA), (totalLiquidity * amountInB) / poolB);
        assertEq(liquidityOut, expectedLiquidityOut, "liquidityOut does not match expectedLiquidityOut");
    }

    function test_getDualSidedMintLiquidityOutAmount_usingReservoirB(
        uint256 totalLiquidity,
        uint256 amountInA,
        uint256 amountInB,
        uint256 poolA,
        uint256 poolB,
        uint256 reservoirB
    ) public {
        // Pools will be capped by uint112
        vm.assume(poolA < type(uint112).max);
        vm.assume(poolB < type(uint112).max);

        // Function reverts with div by zero if either of these are zero
        vm.assume(poolA > 0 && poolB > 0);

        // Ensuring we don't overflow
        if (amountInA > 0) {
            vm.assume(totalLiquidity < (type(uint256).max / amountInA));
        }
        if (amountInB > 0) {
            vm.assume(totalLiquidity < (type(uint256).max / amountInB));
        }
        vm.assume(reservoirB < (type(uint256).max - poolB));

        uint256 liquidityOut =
            PairMath.getDualSidedMintLiquidityOutAmount(totalLiquidity, amountInA, amountInB, poolA, poolB + reservoirB);
        uint256 expectedLiquidityOut =
            Math.min((totalLiquidity * amountInA) / poolA, (totalLiquidity * amountInB) / (poolB + reservoirB));
        assertEq(liquidityOut, expectedLiquidityOut, "liquidityOut does not match expectedLiquidityOut");
    }

    function test_getSingleSidedMintLiquidityOutAmountA(
        uint256 totalLiquidity,
        uint112 mintAmountA,
        uint256 totalA,
        uint256 totalB,
        uint256 movingAveragePriceA
    ) public {
        // Totals will be capped by 2 * type(uint112).max (both pools and res are capped by 2**112) and non-zero
        totalA = uint112(bound(totalA, 1, uint256(type(uint112).max) * 2));
        totalB = uint112(bound(totalB, 1, uint256(type(uint112).max) * 2));

        // Ensuring movingAveragePriceA can't be 0 and must be valid Q112
        movingAveragePriceA = bound(movingAveragePriceA, 1, type(uint224).max);

        uint256 tokenAToSwap =
            Math.mulDiv(mintAmountA, totalB, Math.mulDiv(movingAveragePriceA, totalA + mintAmountA, 2 ** 112) + totalB);
        uint256 expectedSwappedReservoirAmountB = Math.mulDiv(tokenAToSwap, movingAveragePriceA, 2 ** 112);
        uint256 tokenARemaining = mintAmountA - tokenAToSwap;

        // TotalLiquidity is non-zero
        vm.assume(totalLiquidity > 0);
        // Ensuring that we don't trigger an overflow in the intermediate `getDualSidedMintLiquidityOutAmount()` call
        // amountInA * totalLiquidity < type(uint256).max
        vm.assume(tokenARemaining < type(uint256).max / totalLiquidity);
        // amountInB * totalLiquidity < type(uint256).max
        vm.assume(expectedSwappedReservoirAmountB < type(uint256).max / totalLiquidity);

        uint256 expectedLiquidityOut = PairMath.getDualSidedMintLiquidityOutAmount(
            totalLiquidity,
            tokenARemaining,
            expectedSwappedReservoirAmountB,
            totalA + tokenAToSwap,
            totalB - expectedSwappedReservoirAmountB
        );

        (uint256 liquidityOut, uint256 swappedReservoirAmountB) = PairMath.getSingleSidedMintLiquidityOutAmountA(
            totalLiquidity, mintAmountA, totalA, totalB, movingAveragePriceA
        );
        assertEq(
            swappedReservoirAmountB,
            expectedSwappedReservoirAmountB,
            "swappedReservoirAmountB does not match expected amounts"
        );
        assertEq(liquidityOut, expectedLiquidityOut, "liquidityOut does not match expectedLiquidityOut");
    }

    function test_getSingleSidedMintLiquidityOutAmountB(
        uint256 totalLiquidity,
        uint112 mintAmountB,
        uint256 totalA,
        uint256 totalB,
        uint256 movingAveragePriceA
    ) public {
        // Totals will be capped by 2 * type(uint112).max (both pools and res are capped by 2**112) and non-zero
        totalA = uint112(bound(totalA, 1, uint256(type(uint112).max) * 2));
        totalB = uint112(bound(totalB, 1, uint256(type(uint112).max) * 2));

        // Ensuring movingAveragePriceA can't be 0 and must be valid Q112
        movingAveragePriceA = bound(movingAveragePriceA, 1, type(uint224).max);

        uint256 tokenBToSwap =
            (mintAmountB * totalA) / (((2 ** 112 * (totalB + mintAmountB)) / movingAveragePriceA) + totalA);
        // Inverse price so again we can use it without overflow risk
        uint256 expectedSwappedReservoirAmountA = (tokenBToSwap * (2 ** 112)) / movingAveragePriceA;
        uint256 tokenBRemaining = mintAmountB - tokenBToSwap;

        // TotalLiquidity is non-zero
        vm.assume(totalLiquidity > 0);
        // Ensuring that we don't trigger an overflow in the intermediate `getDualSidedMintLiquidityOutAmount()` call
        // amountInA * totalLiquidity < type(uint256).max
        vm.assume(expectedSwappedReservoirAmountA < type(uint256).max / totalLiquidity);
        // amountInB * totalLiquidity < type(uint256).max
        vm.assume(tokenBRemaining < type(uint256).max / totalLiquidity);

        uint256 expectedLiquidityOut = PairMath.getDualSidedMintLiquidityOutAmount(
            totalLiquidity,
            expectedSwappedReservoirAmountA,
            tokenBRemaining,
            totalA - expectedSwappedReservoirAmountA,
            totalB + tokenBToSwap
        );

        (uint256 liquidityOut, uint256 swappedReservoirAmountA) = PairMath.getSingleSidedMintLiquidityOutAmountB(
            totalLiquidity, mintAmountB, totalA, totalB, movingAveragePriceA
        );
        assertEq(
            swappedReservoirAmountA,
            expectedSwappedReservoirAmountA,
            "swappedReservoirAmountA does not match expected amounts"
        );
        assertEq(liquidityOut, expectedLiquidityOut, "liquidityOut does not match expectedLiquidityOut");
    }

    function test_getDualSidedBurnOutputAmounts(
        uint256 totalLiquidity,
        uint256 liquidityIn,
        uint256 totalA,
        uint256 totalB
    ) public {
        // Ensuring we don't divide by zero
        vm.assume(totalLiquidity > 0);

        // Ensuring we don't overflow
        vm.assume(liquidityIn == 0 || totalA < type(uint256).max / liquidityIn);
        vm.assume(liquidityIn == 0 || totalB < type(uint256).max / liquidityIn);

        (uint256 amountOutA, uint256 amountOutB) =
            PairMath.getDualSidedBurnOutputAmounts(totalLiquidity, liquidityIn, totalA, totalB);

        uint256 expectedAmountOutA = (totalA * liquidityIn) / totalLiquidity;
        uint256 expectedAmountOutB = (totalB * liquidityIn) / totalLiquidity;

        assertEq(amountOutA, expectedAmountOutA, "amountOutA does not match expectedAmountOutA");
        assertEq(amountOutB, expectedAmountOutB, "amountOutB does not match expectedAmountOutB");
    }

    function test_getSingleSidedBurnOutputAmountA(
        uint256 totalLiquidity,
        uint256 liquidityIn,
        uint256 totalA,
        uint256 totalB,
        uint256 movingAveragePriceA
    ) public {
        // Totals will be capped by 2 * type(uint112).max (both pools and res are capped by 2**112) and non-zero
        totalA = uint112(bound(totalA, 1, uint256(type(uint112).max) * 2));
        totalB = uint112(bound(totalB, 1, uint256(type(uint112).max) * 2));

        // Ensuring we don't divide by zero
        vm.assume(totalLiquidity > 0);
        // Ensuring we don't overflow
        vm.assume(liquidityIn == 0 || totalA < type(uint256).max / liquidityIn);
        vm.assume(liquidityIn == 0 || totalB < type(uint256).max / liquidityIn);

        // Ensuring movingAveragePriceA can't be 0 and must be valid Q112
        movingAveragePriceA = bound(movingAveragePriceA, 1, type(uint224).max);

        (uint256 internalAmountOutA, uint256 internalAmountOutB) =
            PairMath.getDualSidedBurnOutputAmounts(totalLiquidity, liquidityIn, totalA, totalB);
        // amountOutB must be capped by 2**113 since it is from the bPool and bRes
        vm.assume(internalAmountOutB < uint256(type(uint112).max) * 2);
        uint256 expectedSwappedReservoirAmountA = (internalAmountOutB * (2 ** 112)) / movingAveragePriceA;

        (uint256 amountOutA, uint256 swappedReservoirAmountA) =
            PairMath.getSingleSidedBurnOutputAmountA(totalLiquidity, liquidityIn, totalA, totalB, movingAveragePriceA);

        // amountOutA == (A from dual-burn) + (A from swap)
        assertEq(
            swappedReservoirAmountA,
            expectedSwappedReservoirAmountA,
            "swappedReservoirAmountA does not match expected amounts"
        );
        assertEq(
            amountOutA,
            internalAmountOutA + expectedSwappedReservoirAmountA,
            "amountOutA does not match expected amounts"
        );
    }

    function test_getSingleSidedBurnOutputAmountB(
        uint256 totalLiquidity,
        uint256 liquidityIn,
        uint256 totalA,
        uint256 totalB,
        uint256 movingAveragePriceA
    ) public {
        // Totals will be capped by 2 * type(uint112).max (both pools and res are capped by 2**112) and non-zero
        totalA = uint112(bound(totalA, 1, uint256(type(uint112).max) * 2));
        totalB = uint112(bound(totalB, 1, uint256(type(uint112).max) * 2));

        // Ensuring we don't divide by zero
        vm.assume(totalLiquidity > 0);
        // Ensuring we don't overflow
        vm.assume(liquidityIn == 0 || totalA < type(uint256).max / liquidityIn);
        vm.assume(liquidityIn == 0 || totalB < type(uint256).max / liquidityIn);

        // Ensuring movingAveragePriceA can't be 0 and must be valid Q112
        movingAveragePriceA = bound(movingAveragePriceA, 1, type(uint224).max);

        (uint256 internalAmountOutA, uint256 internalAmountOutB) =
            PairMath.getDualSidedBurnOutputAmounts(totalLiquidity, liquidityIn, totalA, totalB);
        // amountOutA must be capped by 2**113 since it is from the aPool and aRes
        vm.assume(internalAmountOutA < uint256(type(uint112).max) * 2);
        uint256 expectedSwappedReservoirAmountB = Math.mulDiv(internalAmountOutA, movingAveragePriceA, 2 ** 112);
        // swappedReservoirAmountB must be capped by 2**112 since it is from the bRes
        vm.assume(expectedSwappedReservoirAmountB < uint256(type(uint112).max));

        (uint256 amountOutB, uint256 swappedReservoirAmountB) =
            PairMath.getSingleSidedBurnOutputAmountB(totalLiquidity, liquidityIn, totalA, totalB, movingAveragePriceA);

        // amountOutB == (B from dual-burn) + (B from swap)
        assertEq(
            swappedReservoirAmountB,
            expectedSwappedReservoirAmountB,
            "swappedReservoirAmountB does not match expected amounts"
        );
        assertEq(
            amountOutB,
            internalAmountOutB + expectedSwappedReservoirAmountB,
            "amountOutB does not match expected amounts"
        );
    }

    function test_getProtocolFeeLiquidityMinted(uint256 totalLiquidity, uint256 kLast, uint256 k) public {
        // Ensuring we don't underflow
        vm.assume(kLast <= k);

        // Ensuring we don't divide by zero
        vm.assume(k != 0 || kLast != 0);

        // Ensuring we don't overflow (rootK - rootKLast will be bounded by 2^128)
        vm.assume(totalLiquidity < type(uint128).max);

        uint256 liquidityOut = PairMath.getProtocolFeeLiquidityMinted(totalLiquidity, kLast, k);

        uint256 rootKLast = Math.sqrt(kLast);
        uint256 rootK = Math.sqrt(k);
        uint256 expectedLiquidityOut = (totalLiquidity * (rootK - rootKLast)) / ((5 * rootK) + rootKLast);

        assertEq(liquidityOut, expectedLiquidityOut, "liquidityOut does not match expectedLiquidityOut");
    }
}
